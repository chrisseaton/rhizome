# Copyright (c) 2017 Chris Seaton
#
# Permission is hereby granted, free of charge, to any person obtaining
# a copy of this software and associated documentation files (the
# "Software"), to deal in the Software without restriction, including
# without limitation the rights to use, copy, modify, merge, publish,
# distribute, sublicense, and/or sell copies of the Software, and to
# permit persons to whom the Software is furnished to do so, subject to
# the following conditions:
#
# The above copyright notice and this permission notice shall be
# included in all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
# EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
# MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
# NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE
# LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION
# OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION
# WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

require 'set'

module RubyJIT
  module IR

    class Builder

      attr_reader :graph

      def initialize
        @graph = Graph.new
      end

      def targets(insns)
        targets = Set.new

        targets.add 0 unless insns.empty?

        insns.each_with_index do |insn, index|
          if [:branch, :branchif].include?(insn.first)
            targets.add insn[1]
            targets.add index + 1 if insn.first == :branchif
          end
        end

        targets.to_a.sort
      end

      BasicBlock = Struct.new(:start, :insns, :prev, :next)

      def basic_blocks(insns)
        blocks = {}

        targets = targets(insns)

        targets.each_with_index do |start, index|
          if index == targets.size - 1
            last = insns.size
          else
            last = targets[index + 1]
          end

          block_insns = insns.slice(start, last - start)

          last_insn = block_insns.last

          next_blocks = []
          next_blocks.push last_insn[1]        if [:branch, :branchif].include?(last_insn.first)
          next_blocks.push targets[index + 1]  unless [:branch, :return].include?(last_insn.first)

          blocks[start] = BasicBlock.new(start, block_insns, [], next_blocks)
        end

        blocks.values.each do |block|
          block.next.each do |n|
            blocks[n].prev.push block.start
          end
        end

        blocks
      end

      GraphFragment = Struct.new(:region, :last_node, :last_side_effect, :names_out, :stack_out)

      def basic_block_to_graph(names_in, stack_in, insns)
        region = Node.new(:region)
        last_node = nil
        last_side_effect = region

        names = names_in.dup
        stack = stack_in.dup

        insns.each do |insn|
          case insn.first
            when :trace
              last_node = Node.new(:trace, line: insn[1])
            when :self
              last_node = Node.new(:self)
              stack.push last_node
            when :arg
              last_node = Node.new(:arg, n: insn[1])
              stack.push last_node
            when :load
              stack.push names[insn[1]]
            when :store
              names[insn[1]] = stack.pop
            when :push
              last_node = Node.new(:constant, value: insn[1])
              stack.push last_node
            when :send
              name = insn[1]
              argc = insn[2]
              send_node = Node.new(:send, name: name)
              argc.times do
                arg_node = stack.pop
                arg_node.output_to :value, send_node, :args
              end
              receiver_node = stack.pop
              receiver_node.output_to :value, send_node, :receiver
              stack.push send_node
              last_node = send_node
            when :not
              value_node = stack.pop
              not_node = Node.new(:not)
              value_node.output_to :value, not_node
              stack.push not_node
              last_node = not_node
            when :branch
              branch_node = Node.new(:branch)
              last_node = branch_node
            when :branchif
              value_node = stack.pop
              branchif_node = Node.new(:branchif)
              value_node.output_to :value, branchif_node, :condition
              last_node = branchif_node
            when :return
              last_node = stack.last
            else
              raise 'unknown instruction'
          end

          if [:trace, :send].include?(insn.first)
            last_side_effect.output_to :control, last_node
            last_side_effect = last_node
          end
        end

        GraphFragment.new(region, last_node, last_side_effect, names, stack)
      end

    end

  end
end
