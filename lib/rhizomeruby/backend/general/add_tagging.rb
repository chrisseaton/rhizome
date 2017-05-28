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

      # Replaces high level operations on fixnums with low level integer
      # operations with tag and untag operations.

      class AddTagging

        def run(graph)
          modified = false
          
          
          graph.find_nodes(:kind_is?).each do |kind_is|
            case kind_is.props[:kind]
            when :fixnum
              # Replace kind_is?(fixnum) with is_tagged_fixnum?
              kind_is.replace IR::Node.new(:is_tagged_fixnum?)
            when Module
              # This is a hack - replace kind_is?(Module) with just
              # not(is_tagged_fixnum?).
              is_tagged = IR::Node.new(:is_tagged_fixnum?)
              not_is_tagged = IR::Node.new(:not)
              is_tagged.output_to :value, not_is_tagged
              kind_is.replace not_is_tagged, not_is_tagged, [is_tagged]
            end
          end
          
          # Replace fixnum_add(a, b) with tag_fixnum(int64_add(untag_fixnum(a), untag_fixnum(b))), etc

          graph.find_nodes(:fixnum_add, :fixnum_sub, :fixnum_mul).each do |n|
            n.inputs.edges.dup.each do |input|
              if input.value?
                input.interdict IR::Node.new(:untag_fixnum), :value, :value
              end
            end

            tag_nodes = []
            
            n.outputs.edges.dup.each do |output|
              if output.value?
                tag_node = IR::Node.new(:tag_fixnum)
                tag_nodes.push tag_node
                output.interdict tag_node, :value, :value
              end
            end

            if n.has_control_output?
              control = n.outputs.edges.select { |e| e.control? }.first

              # We've kept track of all the tag nodes we added, and we want to
              # add a control flow edge from the tag to wherever control went
              # after the add as otherwise the scheduler ends up with nodes
              # coming out of the last control-flow node in a basic block,
              # which it struggles to schedule correctly. We should really fix
              # the scheduler instead.

              # This causes control-flow diamonds in redundant_multiply!

              tag_nodes.each do |tag_node|
                n.output_to :control, tag_node
                tag_node.output_to :control, control.to, control.input_name
                control.remove
              end
            end

            lowered = {
                fixnum_add: :int64_add,
                fixnum_sub: :int64_sub,
                fixnum_mul: :int64_mul
            }[n.op]
            
            n.replace IR::Node.new(lowered, argc: 1)
            
            modified |= true
          end

          modified
        end
        
      end

    end
  end
end
