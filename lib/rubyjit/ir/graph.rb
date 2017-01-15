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

    class Graph

      attr_reader :start
      attr_reader :finish

      def initialize
        @start = Node.new(:start)
        @finish = Node.new(:finish)
        start.output_to(:control, finish)
      end

      def visit_nodes
        worklist = [@start]
        visited = Set.new
        until worklist.empty?
          node = worklist.pop
          if visited.add?(node)
            yield node
            worklist.push *node.inputs.values.flatten
            worklist.push *node.outputs.values.flatten
          end
        end
      end

      def find_node(op=nil)
        visit_nodes do |node|
          if !op || node.op == op
            if !block_given? || yield(node)
              return node
            end
          end
        end
      end

      def contains?(&block)
        not find_node(&block).nil?
      end

      def size
        count = 0
        visit_nodes do
          count += 1
        end
        count
      end

      def self.from_fragment(fragment)
        graph = RubyJIT::IR::Graph.new
        graph.start.output_to :control, fragment.region
        fragment.last_side_effect.output_to :control, graph.finish
        fragment.last_node.output_to :value, graph.finish
        graph
      end

    end

  end
end
