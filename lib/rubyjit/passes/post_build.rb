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
          # Remove jump and input nodes, as after construction both of these
          # are just going to sit on edges with one input and one output, and
          # we might as well directly connect the nodes that they are between.
          # Also remove merges that have only one control input.

          if [:jump, :input].include?(n.op) || (n.op == :merge && n.outputs.size == 1)
            # For each input edge...

            n.inputs.edges.each do |input|
              # ...connect them to each output the node had.

              n.outputs.edges.each do |output|
                input.from.output_to input.output_name, output.to, output.input_name
              end
            end

            # Then remove the node from the graph.

            n.remove
            modified |= true
          end
        end

        modified
      end

    end

  end
end
