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
require 'tempfile'

module RubyJIT
  module IR

    # A visualiser for our intermediate representation graphs, that uses the
    # Graphviz language and the dot layout tool to generate PDFs.

    class Graphviz
      
      # Create a visualiser for a given graph, or a graph fragment.

      def initialize(graph)
        case graph
          when Graph
            @nodes = graph.all_nodes
          when Builder::GraphFragment
            @nodes = Graph.from_fragment(graph).all_nodes.reject do |n|
              [:start, :finish].include?(n.op)
            end
          else
            raise 'unknown graph type'
        end
      end
      
      # Visualise the graph in the given file, which will be a PDF.
      
      def visualise(file)
        dot_file = Tempfile.new('graph')
        begin
          write dot_file
          dot_file.close
          `dot #{dot_file.path} -Tpdf -o#{file}`
        ensure
          dot_file.delete
        end
      end
      
      # Write the graph in the Graphgiz language.

      def write(out)
        out.puts 'digraph {'

        @nodes.each do |node|
          out.puts "  #{id(node)}[label=\"#{node_label(node)}\"];"

          node.outputs.edges.each do |edge|
            attrs = {
                color: edge_color(edge),
                label: edge_label(edge)
            }

            # We draw control flow as going from output to input, and data
            # flow as input back to output. It helps to show that you run
            # control in the order shown, and you obtain the values you need
            # in the order shown. But we don't store them like that
            # internally, so swap them around here.

            unless edge.control?
              attrs[:dir] = 'back'
            end

            attr_s = attrs.reject { |k, v| v.nil? }.map { |k,v| "#{k}=\"#{v}\"" }.join(', ')

            out.puts "  #{id(edge.from)} -> #{id(edge.to)}[#{attr_s}];"
          end
        end

        out.puts '}'
      end
      
      # Use the Ruby object_id to identify nodes, as it is guaranteed to be
      # unique.

      def id(node)
        "node#{node.object_id}"
      end
      
      # The label to use for a given node. We use knowledge of the different
      # operations in our nodes to give a concise, meaningful title, rather than
      # dumping all the information we have.

      def node_label(node)
        case node.op
          when :arg
            "arg(#{node.props[:n]})"
          when :send
            '#' + node.props[:name].to_s
          when :trace
            "trace(#{node.props[:line]})"
          when :constant
            "const(#{node.props[:value]})"
          else
            node.op.to_s
        end
      end
      
      # The label to use for a given edge. Many edges pass only control or the
      # generic 'value' value, so we don't want to print that all over the
      # graph. Use interesting labels, or nothing at all.

      def edge_label(edge)
        if edge.names.all? { |n| n == :control} || edge.names.all? { |n| n == :value}
          nil
        elsif edge.names.any? { |n| n == :control} || edge.names.any? { |n| n == :value}
          edge.names.reject { |n| [:control, :value].include?(n) }.first
        else
          "#{edge.output_name}→#{edge.input_name}"
        end
      end
      
      # Show control edges in red, data edges in blue.

      def edge_color(edge)
        if edge.names.include?(:control)
          :red
        else
          :blue
        end
      end

    end

  end
end
