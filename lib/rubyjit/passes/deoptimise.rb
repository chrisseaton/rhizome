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

require 'set'

module RubyJIT
  module Passes

    # An optimisation pass to replace uncommon branches with deoptimisation
    # by transfer to interpreter.

    class Deoptimise

      def run(graph)
        modified = false

        graph.find_nodes(:branch).dup.each do |branch|
          true_branch = branch.outputs.with_output_name(:true).to_node
          false_branch = branch.outputs.with_output_name(:false).to_node
          
          # Branches are uncommon if the first node on them is marked as such.
          
          true_uncommon = true_branch.props[:uncommon]
          false_uncommon = false_branch.props[:uncommon]
          
          # If either is uncommon we'll deoptimise...
          
          if true_uncommon || false_uncommon
            # ...but we're not prepared for them both to be uncommon.
            raise if true_uncommon && false_uncommon
            
            # The branch becomes a guard.
            
            guard = IR::Node.new(:guard)
            branch.replace guard
            
            # We're going to remove one side...
            
            if true_uncommon
              remove_branch = true_branch
              # ...and if it's the true branch we then need to negate the condition.
              guard.inputs.with_input_name(:condition).edges.first.interdict IR::Node.new(:not)
            else
              remove_branch = false_branch
            end
            
            # We need to do our own dead code elimination based on removing that
            # side of the branch, as people are still using the values at the
            # moment. We'll use a work list and remove users of removed values.
            
            to_remove = Set.new
            consider_removing = []
            
            to_remove.add remove_branch
            consider_removing.push *remove_branch.outputs.control_edges.to_nodes
            
            until consider_removing.empty?
              consider = consider_removing.pop
              
              if consider.inputs.control_edges.from_nodes.all? { |i| to_remove.include?(i) }
                to_remove.add consider
              end
            end
            
            # We'll actually defer the removal to here so the graph doesn't
            # get into confusing states while we search it for dead code.
            
            to_remove.each do |remove|
              remove.remove
            end
            
            # Look for merges that now only merge from one control-flow path,
            # and remove them.
            
            graph.find_nodes(:merge).dup.each do |merge|
              if merge.inputs.control_edges.from_nodes.size == 1
                raise unless merge.outputs.control_edges.to_nodes.size == 1
                
                merge.inputs.control_edges.from_node.output_to :control, merge.outputs.control_edges.to_node
                merge.remove
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
