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

    # A pass to calculate the value of nodes where the value of all inputs
    # are known.

    class ConstantFold

      def run(graph)
        modified = false

        graph.all_nodes.each do |n|
          case n.op
            when :untag_fixnum
              untag_input = n.inputs.with_input_name(:value).from_node
              if untag_input.op == :tag_fixnum
                # Replace tag(untag(value)) with just value.
                tag_input = untag_input.inputs.with_input_name(:value).from_node
                n.use_instead tag_input
                modified = true
              end
            when :is_tagged_fixnum?
              is_tagged_input = n.inputs.with_input_name(:value).from_node
              if is_tagged_input.op == :tag_fixnum
                # Replace is_tagged?(tag(value)) with just true.
                n.use_instead IR::Node.new(:constant, value: true)
                modified = true
              end
          end

          break if modified
        end

        modified
      end

    end

  end
end
