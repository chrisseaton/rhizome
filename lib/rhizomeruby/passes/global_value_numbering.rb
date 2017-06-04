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

    # A pass to perform global-value-numbering in order to eliminate constant
    # sub-expressions, replacing multiple nodes that compute the same value
    # with just one of the nodes.

    class GlobalValueNumbering

      def run(graph)
        modified = false

        # We'll cache the value identity of nodes because it could be expensive
        # to compute.

        value_identities = {}

        # Store a single node for each value identity.

        canonical = {}

        # We'll be modifying the graph quite a bit so work on a single copy of
        # value nodes.

        value_nodes = graph.all_nodes.reject(&:has_control_output?)

        # Cache value identities of nodes and find a canonical node for each value.

        value_nodes.each do |n|
          value_identity = n.value_identity
          value_identities[n] = value_identity
          canonical[value_identity] = n
        end

        # Replace nodes with the canonical versions if they aren't it.

        value_nodes.each do |n|
          next if n.op == :immediate

          c = canonical[value_identities[n]]
          if c != n
            n.use_instead c
            modified = true
          end
        end

        modified
      end

    end

  end
end
