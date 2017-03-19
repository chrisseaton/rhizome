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
            @fragment = false
          when Builder::GraphFragment
            @nodes = Graph.from_fragment(graph).all_nodes.reject { |n| n.op == :start }
            @fragment = true
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
          attrs = {
              label: node_label(node)
          }

          # We don't draw unresolved input nodes - the edges just go into
          # empty space.

          if node.op == :input && !node.has_input?
            attrs[:style] = 'invis'
          end

          # Draw the finish nodes for fragments as 'result' nodes so it's
          # clear they're from a fragment.

          if node.op == :finish && @fragment
            attrs[:label] = 'result'
          end

          attr_s = attrs.reject { |k, v| v.nil? }.map { |k,v| "#{k}=\"#{v}\"" }.join(', ')

          out.puts "  #{id(node)}[#{attr_s}];"

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

            unless edge.control? || edge.schedule?
              attrs[:dir] = 'back'
            end

            # We draw edges that go to graph fragment input as orange...

            if node.op == :input
              attrs[:color] = 'orange'

              # ...and dash it if it has not been connected yet.

              attrs[:style] = 'dashed' unless node.has_input?
            end

            # The edge from the merge to a phi is dashed.

            if node.op == :merge && edge.to.op == :phi
              attrs[:style] = 'dashed'
            end

            # Global schedule edges are dark green.

            if edge.input_name == :global_schedule
              attrs[:color] = 'darkgreen'
              attrs[:style] = 'dashed'
            end

            # Local schedule edges are dark green and dashed.

            if edge.input_name == :local_schedule
              attrs[:color] = 'darkgreen'
              attrs[:constraint] = 'false'
            end

            # Combine all the attributes.

            attr_s = attrs.reject { |k, v| v.nil? }.map { |k,v| "#{k}=\"#{v}\"" }.join(', ')

            out.puts "  #{id(edge.from)} -> #{id(edge.to)}[#{attr_s}];"
          end

          # If this is a fragment, draw some extra dashed orange lines for
          # that are missing otherwise.

          if @fragment
            case node.op
              when :merge
                out.puts "  #{id(node)}_in[style=\"\invis\"];"
                out.puts "  #{id(node)}_in -> #{id(node)}[color=\"orange\",style=\"dashed\"];"
              when :jump
                out.puts "  #{id(node)}_target[style=\"\invis\"];"
                out.puts "  #{id(node)} -> #{id(node)}_target[color=\"orange\",style=\"dashed\"];"
              when :branch
                out.puts "  #{id(node)}_true[style=\"\invis\"];"
                out.puts "  #{id(node)}_false[style=\"\invis\"];"
                out.puts "  #{id(node)} -> #{id(node)}_true[color=\"orange\",style=\"dashed\"];"
                out.puts "  #{id(node)} -> #{id(node)}_false[color=\"orange\",style=\"dashed\"];"
              when :finish
                out.puts "  #{id(node)}_target[style=\"\invis\"];"
                out.puts "  #{id(node)} -> #{id(node)}_target[color=\"orange\",style=\"dashed\"];"
            end
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
            label = "arg(#{node.props[:n]})"
          when :send
            label = '#' + node.props[:name].to_s
          when :trace
            label = "trace(#{node.props[:line]})"
          when :constant
            label = "const(#{node.props[:value]})"
          else
            label = node.op.to_s
        end

        sequence = node.props[:sequence]
        label += " ↓#{sequence}" if sequence

        register = node.props[:register]
        label += " →#{register}" if register

        label
      end
      
      # The label to use for a given edge. Many edges pass only control or the
      # generic 'value' value, so we don't want to print that all over the
      # graph. Use interesting labels, or nothing at all.

      def edge_label(edge)
        all_control = edge.names.all? { |n| n == :control}
        any_control = edge.names.any? { |n| n == :control}
        all_schedule = edge.names.all? { |n| [:global_schedule, :local_schedule].include?(n)}
        all_value = edge.names.all? { |n| n == :value}
        any_value = edge.names.any? { |n| n == :value}
        merge_or_phi = [:merge, :phi].include?(edge.to.op)
        merge_to_phi = edge.from.op == :merge && edge.to.op == :phi

        if ((all_control || all_value) && !merge_or_phi) || merge_to_phi || all_schedule
          nil
        elsif [:merge, :phi].include?(edge.to.op)
          edge.input_name =~ /\w+\((\d+)\)/
          $1.to_s
        elsif any_control || any_value
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
