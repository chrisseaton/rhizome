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
  module Passes

    # The post-build pass runs after the construction of a graph and tidies it
    # up, removing nodes and edges that were just added as part of the
    # construction as scaffolding and aren't actually needed when the graph
    # has been connected up.

    class PostBuild

      def run(graph)
        modified = false

        # Look at each node.

        graph.all_nodes.each do |n|
          # Remove jump and connector nodes, as after construction both of these
          # are just going to sit on edges with one input and one output, and
          # we might as well directly connect the nodes that they are between.
          # Also remove merges that have only one control input.

          if [:jump, :connector].include?(n.op) || (n.op == :merge && n.outputs.size == 1)
            # For each input edge connect them to each output the node had,
            # separating control and data edges.

            n.inputs.edges.each do |input|
              n.outputs.edges.each do |output|
                if input.control? == output.control?
                  input.from.output_to dominant_name(input.output_name, output.output_name), output.to, dominant_name(input.input_name, output.input_name)
                end
              end
            end

            # Then remove the node from the graph.

            n.remove
            modified = true
          end
        end

        modified
      end

      # We often have two edges passing through a connection node, where one
      # name is important and means something specific and the other one is
      # something generic like control or value. This method returns the
      # important one.

      def dominant_name(*names)
        %i(true false).each do |d|
          return d if names.include?(d)
        end
        names.last
      end

    end

  end
end
