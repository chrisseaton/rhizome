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

# The mechanism that we use to call native functions and access native memory
# varies by the implementation of Ruby.

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

    end

  end
end
