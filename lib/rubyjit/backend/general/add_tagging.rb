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
  module Backend
    module General

      # Replaces high level operations on fixnums with low level integer
      # operations with tag and untag operations.

      class AddTagging

        def run(graph)
          modified = false
          
          # Replace kind_is?(fixnum) with is_tagged_fixnum?
          
          graph.find_nodes(:kind_is?).each do |kind_is|
            if kind_is.props[:kind] == :fixnum
              kind_is.replace IR::Node.new(:is_tagged_fixnum?)
            end
          end
          
          # Replace fixnum_add(a, b) with tag_fixnum(int64_add(untag_fixnum(a), untag_fixnum(b)))

          graph.find_nodes(:fixnum_add).each do |add|
            add.inputs.edges.dup.each do |input|
              if input.value?
                input.interdict IR::Node.new(:untag_fixnum)
              end
            end
            
            add.outputs.edges.dup.each do |output|
              if output.value?
                output.interdict IR::Node.new(:tag_fixnum)
              end
            end
            
            add.replace IR::Node.new(:int64_add)
            
            modified |= true
          end

          modified
        end
        
      end

    end
  end
end
