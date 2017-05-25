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

require 'rhizomeruby'

describe Rhizome::Backend::General::AddTagging do

  before :each do
    @graph = Rhizome::IR::Graph.new
    @add_tagging = Rhizome::Backend::General::AddTagging.new
  end

  describe '#run' do

    it 'replaces kind_is?(fixnum) with is_tagged_fixnum?' do
      kind_is = Rhizome::IR::Node.new(:kind_is?, kind: :fixnum)
      @graph.start.output_to :value, kind_is
      kind_is.output_to :value, @graph.finish
      @graph.start.output_to :value, @graph.finish

      expect(@graph.find_node(:kind_is?)).to_not be_nil

      @add_tagging.run @graph

      expect(@graph.find_node(:kind_is?)).to be_nil
      expect(@graph.find_node(:is_tagged_fixnum?)).to_not be_nil
    end

    it 'replaces fixnum_add(a, b) with tag_fixnum(int64_add(untag_fixnum(a), untag_fixnum(b)))' do
      a = Rhizome::IR::Node.new(:a)
      b = Rhizome::IR::Node.new(:b)
      fixnum_add = Rhizome::IR::Node.new(:fixnum_add)
      @graph.start.output_to :control, fixnum_add
      fixnum_add.output_to :control, @graph.finish
      a.output_to :value, fixnum_add, :receiver
      b.output_to :value, fixnum_add, :'arg(0)'
      fixnum_add.output_to :value, @graph.finish

      expect(@graph.find_node(:fixnum_add)).to_not be_nil

      @add_tagging.run @graph

      expect(@graph.find_node(:fixnum_add)).to be_nil
      expect(@graph.find_nodes(:untag_fixnum).size).to eq 2
      expect(@graph.find_node(:int64_add)).to_not be_nil
      expect(@graph.find_node(:tag_fixnum)).to_not be_nil
    end

  end

end
