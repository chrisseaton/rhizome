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

    class Node

      attr_reader :op
      attr_reader :props
      attr_reader :inputs
      attr_reader :outputs

      def initialize(op, props={})
        @op = op
        @props = props
        @inputs = EdgeSet.new([])
        @outputs = EdgeSet.new([])
      end

      def output_to(output_name, to, input_name=output_name)
        edge = Edge.new(self, output_name, to, input_name)
        outputs.edges.push edge
        to.inputs.edges.push edge
      end

      def has_control_input?
        inputs.input_names.include?(:control)
      end

      def has_control_output?
        outputs.output_names.include?(:control)
      end

      def inspect
        "Node<#{object_id}, #{op}, #{props}>"
      end

    end

    Edge = Struct.new(:from, :output_name, :to, :input_name)

    class EdgeSet

      attr_reader :edges

      def initialize(edges)
        @edges = edges
      end

      def output_names
        edges.map(&:output_name).uniq
      end

      def input_names
        edges.map(&:input_name).uniq
      end

      def with_output_name(name)
        EdgeSet.new(edges.select { |e| e.output_name == name })
      end

      def with_input_name(name)
        EdgeSet.new(edges.select { |e| e.input_name == name })
      end

      def nodes
        (from_nodes + to_nodes).uniq
      end

      def from_nodes
        edges.map(&:from).uniq
      end

      def to_nodes
        edges.map(&:to).uniq
      end

      def empty?
        edges.empty?
      end

    end

  end
end
