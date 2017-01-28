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

      def build(insns)
        blocks = basic_blocks(insns)

        fragments = {}

        blocks.each_value do |block|
          fragments[block.start] = basic_block_to_graph(block.insns)
        end

        blocks.each_value do |block|
          fragment = fragments[block.start]

          if block.prev.empty?
            @graph.start.output_to :control, fragment.region
          elsif block.prev.size == 1
            prev = block.prev.first
            prev_fragment = fragments[prev]

            fragment.names_in.each do |name, input|
              prev_fragment.names_out[name].output_to :value, input
            end

            fragment.stack_in.each_with_index do |input, index|
              raise 'unsupported'
            end
          else
            fragment.names_in.each do |name, input|
              raise 'unsupported'
            end

            fragment.stack_in.each_with_index do |input, index|
              phi = Node.new(:phi)
              fragment.region.output_to :value, phi

              block.prev.each do |prev|
                prev_fragment = fragments[prev]
                prev_fragment.stack_out[index].output_to :value, phi
              end

              phi.output_to :value, input
            end
          end

          if block.next.empty?
            fragment.last_control.output_to :control, @graph.finish
            fragment.last_node.output_to :value, @graph.finish
          elsif block.next.size == 1
            next_i = block.next.first
            next_fragment = fragments[next_i]

            fragment.last_control.output_to :control, next_fragment.region
          elsif fragment.last_control.op == :branchif
            raise unless block.next.size == 2
            fragment.last_control.output_to :true, fragments[block.next[0]].region, :control
            fragment.last_control.output_to :false, fragments[block.next[1]].region, :control
          else
            raise 'unsupported'
          end
        end
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

      GraphFragment = Struct.new(:names_in, :stack_in, :region, :last_node, :last_control, :names_out, :stack_out)

      def basic_block_to_graph(insns)
        region = Node.new(:region)
        names_in = {}
        stack_in = []
        last_node = nil
        last_control = region
        names = {}
        stack = []

        pop = proc {
          if stack.empty?
            input = Node.new(:input)
            stack_in.unshift input
            input
          else
            stack.pop
          end
        }

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
              name = insn[1]
              value = names[name]
              unless value
                input = Node.new(:input)
                names_in[name] = input
                names[name] = input
                value = input
              end
              stack.push value
            when :store
              names[insn[1]] = pop.call
            when :push
              last_node = Node.new(:constant, value: insn[1])
              stack.push last_node
            when :send
              name = insn[1]
              argc = insn[2]
              send_node = Node.new(:send, name: name)
              argc.times do
                arg_node = pop.call
                arg_node.output_to :value, send_node, :args
              end
              receiver_node = pop.call
              receiver_node.output_to :value, send_node, :receiver
              stack.push send_node
              last_node = send_node
            when :not
              value_node = pop.call
              not_node = Node.new(:not)
              value_node.output_to :value, not_node
              stack.push not_node
              last_node = not_node
            when :branch
              branch_node = Node.new(:branch)
              last_node = branch_node
            when :branchif
              value_node = pop.call
              branchif_node = Node.new(:branchif)
              value_node.output_to :value, branchif_node, :condition
              last_node = branchif_node
            when :return
              last_node = pop.call
              stack.push last_node
            else
              raise 'unknown instruction'
          end

          # branch and branchif aren't really side effects...

          if [:trace, :send, :branch, :branchif].include?(insn.first)
            last_control.output_to :control, last_node
            last_control = last_node
          end
        end

        GraphFragment.new(names_in, stack_in, region, last_node, last_control, names, stack)
      end

    end

  end
end
