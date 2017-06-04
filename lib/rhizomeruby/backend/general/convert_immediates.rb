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
  module Backend
    module General

      # A pass to convert constant input values to immediates where the architecture's instruction
      # encoding supports this.

      class ConvertImmediates

        def initialize(patterns)
          @patterns = patterns
          @ops = patterns.flat_map(&:first)
        end

        def run(graph)
          modified = false

          # Look at each node we can have immediates for.

          graph.find_nodes(*@ops).each do |n|
            # Go through those inputs that can be immediates.

            args = @patterns.find { |p| p.first.include?(n.op) }.last

            args.each do |a|
              arg_edge = n.inputs.with_input_name(a).edges.first
              arg_node = arg_edge.from

              if arg_node.op == :constant
                value = arg_node.props[:value]

                # Replace the edge to the constant with a new immediate node.

                IR::Node.new(:immediate, value: value).output_to :value, n, a
                arg_edge.remove

                modified = true
              end
            end
          end

          modified
        end

      end

    end
  end
end
