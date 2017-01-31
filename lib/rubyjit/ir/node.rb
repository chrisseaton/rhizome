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

module RubyJIT
  module IR

    # A node represents a computation in a Ruby program.

    class Node

      # Nodes have an operation, a hash of property names and values, and
      # arrays of inputs from and outputs to other nodes, which is how they
      # form a graph.

      attr_reader :op, :props, :inputs, :outputs

      # To create a node you specify the operation and the set of properties.

      def initialize(op, props={})
        @op = op
        @props = props
        @inputs = EdgeSet.new([])
        @outputs = EdgeSet.new([])
      end

      # Say that this node sends some kind of output to another node. This
      # creates an edge from this node to the other, so places the other node
      # into the graph if it wasn't already. The output has a name, and the
      # other node has its own name for its input value.

      def output_to(output_name, to, input_name=output_name)
        edge = Edge.new(self, output_name, to, input_name)

        # The operation is symmetrical - both nodes get the edge added.

        outputs.edges.push edge
        to.inputs.edges.push edge
      end

      # Does this node have any inputs?

      def has_input?
        not inputs.empty?
      end

      # Does this node have any control input?

      def has_control_input?
        inputs.input_names.any? { |n| n.to_s.start_with?('control') }
      end

      # Does this node have any control output?

      def has_control_output?
        outputs.output_names.any? { |n| n.to_s.start_with?('control') }
      end

      # Pretty print the node for debugging.

      def inspect
        "Node<#{object_id}, #{op}, #{props}>"
      end

      # Remove a node by removing all its input and output edges.

      def remove
        inputs.edges.dup.each(&:remove)
        outputs.edges.dup.each(&:remove)
      end

    end

    # An edge is a connection from one node to another.

    class Edge

      # An edge has a from node, the name of the value as it is output from
      # that node, a to node, and the name of the value as it is input to that
      # node. There are two names because the nodes may think of the value in
      # different ways. One node may output a remainder from a division
      # operation for example, but the next node may use that value as the
      # argument for a method send.

      attr_reader :from, :output_name, :to, :input_name

      def initialize(from, output_name, to, input_name)
        @from = from
        @output_name = output_name
        @to = to
        @input_name = input_name
      end

      # Get both the names.

      def names
        [output_name, input_name]
      end

      # Is this a control edge?

      def control?
        names.any? { |n| n.to_s.start_with?('control') }
      end

      # Remove an edge by removing the references from the nodes to it.

      def remove
        from.outputs.edges.delete self
        to.inputs.edges.delete self
      end

    end

    # An edge set is just a collection of edges with some extra methods for
    # common query operations that you will want to apply to sets of edges.

    class EdgeSet

      attr_reader :edges

      def initialize(edges)
        @edges = edges
      end

      # Get all the output names in this set of edges.

      def output_names
        edges.map(&:output_name).uniq
      end

      # Get all the input names in this set of edges.

      def input_names
        edges.map(&:input_name).uniq
      end

      # Get a new edge set with only edges that have a given output name.

      def with_output_name(name)
        EdgeSet.new(edges.select { |e| e.output_name == name })
      end

      # Get a new edge set with only edges that have a given input name.

      def with_input_name(name)
        EdgeSet.new(edges.select { |e| e.input_name == name })
      end

      # Get all the nodes referenced from these edges.

      def nodes
        (from_nodes + to_nodes).uniq
      end

      # Get all the nodes outputing values.

      def from_nodes
        edges.map(&:from).uniq
      end

      # Get all the nodes inputing values.

      def to_nodes
        edges.map(&:to).uniq
      end

      # Is this set empty?

      def empty?
        edges.empty?
      end

      # How many edges are in the set?

      def size
        edges.size
      end

    end

  end
end
