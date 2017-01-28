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
        # Look at each node.

        graph.all_nodes.each do |n|
          # Remove branch and input nodes, as after construction both of these
          # are just going to sit on edges with one input and one output, and
          # we might as well directly connect the nodes that they are between.

          if [:branch, :input].include?(n.op)
            raise unless n.inputs.size == 1
            input = n.inputs.edges.first.from

            n.outputs.edges.each do |output|
              input.output_to output.output_name, output.to, output.input_name
              output.to.inputs.edges.reject! { |input| input.from == n }
            end

            n.inputs.edges.each do |input|
              input.from.outputs.edges.reject! { |output| output.to == n }
            end
          end
        end
      end

    end

  end
end
