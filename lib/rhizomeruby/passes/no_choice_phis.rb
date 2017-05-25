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

    # An optimisation pass to remove phi nodes where there isn't really any
    # choice - all possibilities point at the same value and all users of
    # the phi node may as well point directly at that value.

    class NoChoicePhis

      def run(graph)
        modified = false

        # Look at each phi node.

        graph.all_nodes.each do |n|
          if n.op == :phi
            # The phi node provides no real choice if there are only two
            # unique inputs. It's two because one is the switch value
            # from the merge node, and the other is the actual value.

            if n.inputs.from_nodes.uniq.size <= 2
              # We've got just one input then.

              input = n.inputs.edges.find { |i| i.from.op != :merge }

              # We only know how to handle the case where the input
              # name is only :value (or the :switch case, which points
              # at the merge node).

              unless n.inputs.edges.all? { |i| [:value, :switch].include?(i.output_name) }
                raise 'unsupported'
              end

              # Point each user of the phi node directly at the phi node's input - the value.

              n.outputs.edges.each do |output|
                input.from.output_to input.output_name, output.to, output.input_name
              end

              # Remove the phi node from the graph.

              n.remove
              modified = true
            end
          end
        end

        modified
      end

    end

  end
end
