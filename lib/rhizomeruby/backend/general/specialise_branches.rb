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

      # Specialise branches for a particular test by taking the test off
      # the condition edge and putting it into the branch as a property.
      # Guards are treated the same way as branches.

      class SpecialiseBranches

        def run(graph)
          modified = false

          graph.find_nodes(:branch, :guard).each do |branch|
            condition = branch.inputs.with_input_name(:condition).from_node
            
            if [:int64_zero?, :int64_not_zero?].include?(condition.op)
              condition.inputs.from_node.output_to :value, branch, :condition
              condition.remove
              
              branch.props[:test] = condition.op
              
              modified |= true
            end
          end

          modified
        end
        
      end

    end
  end
end
