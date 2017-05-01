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

require 'rubyjit'

describe RubyJIT::Backend::General::ExpandTagging do

  before :each do
    @graph = RubyJIT::IR::Graph.new
    @expand_tagging = RubyJIT::Backend::General::ExpandTagging.new
  end

  describe '#run' do

    it 'replaces is_tagged_fixnum?(a) with int64_not_zero?(int64_and(a, 1))' do
      is_tagged_fixnum = RubyJIT::IR::Node.new(:is_tagged_fixnum?)
      @graph.start.output_to :value, is_tagged_fixnum
      is_tagged_fixnum.output_to :value, @graph.finish
      @graph.start.output_to :value, @graph.finish

      expect(@graph.find_node(:is_tagged_fixnum?)).to_not be_nil

      @expand_tagging.run @graph

      expect(@graph.find_node(:is_tagged_fixnum?)).to be_nil
      expect(@graph.find_node(:int64_not_zero?)).to_not be_nil
      expect(@graph.find_node(:int64_and)).to_not be_nil
    end

    it 'replaces untag_fixnum(a) with int64_shift_right(a, 1)' do
      untag_fixnum = RubyJIT::IR::Node.new(:untag_fixnum)
      @graph.start.output_to :value, untag_fixnum
      untag_fixnum.output_to :value, @graph.finish
      @graph.start.output_to :value, @graph.finish

      expect(@graph.find_node(:untag_fixnum)).to_not be_nil

      @expand_tagging.run @graph

      expect(@graph.find_node(:untag_fixnum)).to be_nil
      expect(@graph.find_node(:int64_shift_right)).to_not be_nil
    end

    it 'replaces tag_fixnum(a) with int64_add(int64_shift_left(a, 1), 1)' do
      tag_fixnum = RubyJIT::IR::Node.new(:tag_fixnum)
      @graph.start.output_to :value, tag_fixnum
      tag_fixnum.output_to :value, @graph.finish
      @graph.start.output_to :value, @graph.finish

      expect(@graph.find_node(:tag_fixnum)).to_not be_nil

      @expand_tagging.run @graph

      expect(@graph.find_node(:tag_fixnum)).to be_nil
      expect(@graph.find_node(:int64_add)).to_not be_nil
      expect(@graph.find_node(:int64_shift_left)).to_not be_nil
    end

  end

end
