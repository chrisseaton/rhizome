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

    # A graph is a data structure to represent Ruby code as it is optimised
    # and compiled to machine code.

    class Graph

      # Graphs have start and finish nodes. These are the handles that we keep
      # hold of to be able to access any of the nodes.

      attr_reader :start
      attr_reader :finish

      def initialize
        # Create the start and finish nodes. We would create a control edge to
        # say that the start node has to run before the finish node, but when
        # any other control flow is added this just becomes redundant and
        # complicates the graphs. Create it yourself if you need it.

        @start = Node.new(:start)
        @finish = Node.new(:finish)
      end

      # Yield to a block for each node in the graph.

      def visit_nodes
        # Run a depth-first traversal of the graph with a worklist and a
        # visited set.

        worklist = [@start]
        visited = Set.new
        until worklist.empty?
          node = worklist.pop
          if visited.add?(node)
            yield node
            worklist.push *node.inputs.nodes
            worklist.push *node.outputs.nodes
          end
        end
      end

      # Get a simple array of all nodes in the graph. Useful when you will be
      # mutating the graph and so don't want the traversal running at the same
      # time as your mutation.

      def all_nodes
        nodes = []
        visit_nodes do |node|
          nodes.push node
        end
        nodes
      end

      # Find a node that meets a condition - either a block or a simple
      # comparison by the operation name.

      def find_node(op=nil)
        visit_nodes do |node|
          if !op || node.op == op
            if !block_given? || yield(node)
              return node
            end
          end
        end
      end

      # Find all the nodes that meet a condition - either a block or a simple
      # comparison by the operation name.

      def find_nodes(*ops)
        found = []
        visit_nodes do |node|
          if ops.empty? || ops.include?(node.op)
            if !block_given? || yield(node)
              found.push node
            end
          end
        end
        found
      end

      # Is there a node which meets a condition?

      def contains?(op=nil, &block)
        not find_node(op, &block).nil?
      end

      # How many nodes are there in the graph?

      def size
        count = 0
        visit_nodes do
          count += 1
        end
        count
      end

      # Create a graph from a fragment. It may not still be fully connected,
      # but at least it will be a proper graph object which you can pass into
      # interfaces wanting that.

      def self.from_fragment(fragment)
        graph = RubyJIT::IR::Graph.new
        graph.start.output_to :control, fragment.merge
        fragment.last_control.output_to :control, graph.finish
        fragment.last_node.output_to :value, graph.finish
        graph
      end

    end

  end
end
