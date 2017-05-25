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

      # Expand high-level tagging operations into low-level integer operations.

      class ExpandTagging

        def run(graph)
          modified = false

          # Replace is_tagged_fixnum?(a) with int64_not_zero?(int64_and(a, 1))

          graph.find_nodes(:is_tagged_fixnum?).each do |is_tagged_fixnum|
            one = IR::Node.new(:constant, value: 1)
            and_one = IR::Node.new(:int64_and, argc: 1)
            not_zero = IR::Node.new(:int64_not_zero?)
            
            one.output_to :value, and_one, :'arg(0)'
            and_one.output_to :value, not_zero
            
            is_tagged_fixnum.replace not_zero, not_zero, [and_one], not_zero, :receiver
            
            modified |= true
          end

          # Replace untag_fixnum(a) with int64_shift_right(a, 1)

          graph.find_nodes(:untag_fixnum).each do |untag_fixnum|
            one = IR::Node.new(:constant, value: 1)
            shift_right = IR::Node.new(:int64_shift_right, argc: 1)
            
            one.output_to :value, shift_right, :'arg(0)'
            
            untag_fixnum.replace shift_right, shift_right, [shift_right], shift_right, :receiver
            
            modified |= true
          end

          # Replace tag_fixnum(a) with int64_add(int64_shift_left(a, 1), 1)

          graph.find_nodes(:tag_fixnum).each do |tag_fixnum|
            one = IR::Node.new(:constant, value: 1)
            shift_left = IR::Node.new(:int64_shift_left, argc: 1)
            add = IR::Node.new(:int64_add, argc: 1)
            
            one.output_to :value, shift_left, :'arg(0)'
            shift_left.output_to :value, add, :receiver
            one.output_to :value, add, :'arg(0)'
            
            tag_fixnum.replace add, add, [shift_left], add, :receiver
            
            modified |= true
          end

          modified
        end
        
      end

    end
  end
end
