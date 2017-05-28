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

    # A pass to remove guards that will are redundant because they can never fail.

    class RemoveRedundantGuards

      def run(graph)
        modified = false

        # Look at each guard node.

        graph.find_nodes(:guard).each do |guard|
          # Everything depends on the value of the condition.
          condition = guard.inputs.with_input_name(:condition).from_node
          if condition.op == :constant
            # If the condition is a constant and true then the guard will never fail
            # - remove it. If the guard is a constant false then we will always
            # deoptimise. We should probably have a specific deoptimise node, and float
            # it on the control flow path as far as we can until we reach a side effect,
            # but we haven't implemented that yet.
            raise unless condition.props[:value]
            guard.remove_from_control_flow
            modified = true
            break
          else
            # If the condition isn't a constant then we want to see if the value
            # has ever been guarded before - if it's been guarded and we're still
            # running then it must be true.

            condition_value_identity = condition.value_identity

            # Loop back along the control flow path. We'll just go as far as the start
            # of the basic block, so this is *local* redundant guard removal, becuase
            # it would be complicated to look beyond branches.

            before = guard.inputs.with_input_name(:control).from_nodes
            loop do
              break if before.size > 1
              before = before.first
              break if [:start, :branch, :merge].include?(before.op)
              if before.op == :guard
                before_condition = before.inputs.with_input_name(:condition).from_node
                before_condition_value_identity = before_condition.value_identity
                if condition_value_identity == before_condition_value_identity
                  guard.remove_from_control_flow
                  modified = true
                  break
                end
              end
              before = before.inputs.with_input_name(:control).from_nodes
            end
            break if modified
          end
        end

        modified
      end

    end

  end
end
