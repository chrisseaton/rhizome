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
  module Passes

    # An optimisation pass to float nodes which have become fixed but don't need to be.
    # This happens when sends are inlined to nodes which could be floating but are
    # fixed in the same place as their call during inlining.

    class Refloat

      def run(graph)
        modified = false

        # Look at each node.

        graph.all_nodes.each do |n|
          # Look for nodes that are fixed but don't have side effects.

          if n.fixed? && !n.has_side_effects?
            # Connect each previous control-flow node to the one after this node, and then
            # remove control-flow edges passing through this node.

            after = n.outputs.with_output_name(:control).to_node
            n.inputs.edges.each do |i|
              if i.control?
                i.remove
                i.from.output_to i.output_name, after, i.input_name
              end
            end

            n.outputs.edges.each do |o|
              if o.control?
                o.remove
              end
            end

            modified = true
          end
        end

        modified
      end

    end

  end
end
