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

module Rhizome
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
        # We never want to connect a node to itself.
        raise if to == self

        # Values going into a phi should be named.
        raise input_name.to_s if to.op == :phi && !input_name.to_s.start_with?('value(') && ![:switch, :local_schedule, :global_schedule].include?(input_name)

        # There should not be more than one local schedule edge coming out of a node.
        raise if output_name == :local_schedule && !outputs.with_output_name(:local_schedule).edges.empty?

        edge = Edge.new(self, output_name, to, input_name)

        # The operation is symmetrical - both nodes get the edge added.

        outputs.edges.push edge
        to.inputs.edges.push edge
      end

      # Does this node output to another node?

      def outputs_to?(output_name, to, input_name=output_name)
        outputs.with_output_name(output_name).edges.any? do |edge|
          edge.to == to && input_name == input_name
        end
      end

      # Does this node have any inputs?

      def has_input?
        not inputs.empty?
      end

      # Does this node produce a value?

      def produces_value?
        outputs.edges.any?(&:value?)
      end

      # Does this node have any control input?

      def has_control_input?
        inputs.edges.any?(&:control?)
      end

      # Does this node have any control output?

      def has_control_output?
        outputs.edges.any?(&:control?)
      end

      # Is this node floating? As in, not fixed in an order except by data dependencies.

      def floating?
        not fixed?
      end

      # Is this node fixed? As in, fixed in an order except by data dependencies.

      def fixed?
        has_control_input? || has_control_output?
      end

      # Does this node begin a basic block?

      def begins_block?
        op == :start || op == :merge || inputs.control_edges.from_nodes.any? { |i| i.op == :branch }
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

      # Replace this node with a subgraph of new nodes. Allows the caller to
      # specify the start and finish nodes for control, and then separately
      # any number of nodes which should become users of the data inputs to
      # the current node, and a node which now produces the value that was
      # previously coming from this node.

      def replace(*args)
        Node.replace_multiple self, self, *args
      end

      def self.replace_multiple(existing_start, existing_finish, start, finish=start, users=[start], value=finish, user_input_name=nil)
        existing_start.inputs.edges.each do |edge|
          if edge.control? || edge.frame_state?
            edge.from.output_to edge.output_name, start, edge.input_name
          else
            users.each do |user|
              edge.from.output_to edge.output_name, user, user_input_name || edge.input_name
            end
          end
        end

        existing_finish.outputs.edges.each do |edge|
          if edge.control? || edge.frame_state?
            finish.output_to edge.output_name, edge.to, edge.input_name
          else
            value.output_to edge.output_name, edge.to, edge.input_name
          end
        end

        existing_start.remove
        existing_finish.remove if existing_finish != existing_start
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

      # Is this an edge to a frame state?

      def frame_state?
        names.any? { |n| n == :frame_state }
      end

      # Is this a schedule edge?

      def schedule?
        names.any? { |n| n.to_s.end_with?('schedule') }
      end

      # Is this a value edge?

      def value?
        names.any? { |n| n.to_s.start_with?('value') }
      end
      
      # Insert a node in the middle of this edge.
      
      def interdict(node, inner_output_name=output_name, inner_input_name=input_name)
        remove
        from.output_to output_name, node, inner_output_name
        node.output_to inner_input_name, to, input_name
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

      # Get all the control-flow edges.

      def control_edges
        EdgeSet.new(edges.select(&:control?))
      end

      # Get all the nodes referenced from these edges.

      def nodes
        (from_nodes + to_nodes).uniq
      end

      # Get all the nodes outputing values.

      def from_nodes
        edges.map(&:from).uniq
      end

      # Check that there is a single from node and get it.

      def from_node
        nodes = from_nodes
        raise unless nodes.size == 1
        nodes.first
      end

      # Get all the nodes inputing values.

      def to_nodes
        edges.map(&:to).uniq
      end

      # Check that there is a single to node and get it.

      def to_node
        nodes = to_nodes
        raise unless nodes.size == 1
        nodes.first
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
