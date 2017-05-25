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

    # An optimisation pass to insert safepoints that can deoptimise, and remove
    # nodes that can use safepoints instead.

    class InsertSafepoints

      def run(graph)
        modified = false

        # Remove trace nodes entirely - no deoptimisation nodes are needed
        # because we can stop the compiled code at any point and run in the
        # interpreter - we don't need to be at a certain point in the program
        # to do that.

        graph.find_nodes(:trace).each do |trace|
          # A trace node should just have a single control in and out
          control_from = trace.inputs.with_input_name(:control).from_node
          control_to = trace.outputs.with_output_name(:control).to_node
          control_from.output_to :control, control_to
          trace.remove
          modified = true
        end

        modified
      end

    end

  end
end
