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

describe RubyJIT::Backend::General::SpecialiseBranches do

  before :each do
    @graph = RubyJIT::IR::Graph.new
    @specialise_branches = RubyJIT::Backend::General::SpecialiseBranches.new
  end

  describe '#run' do

    it 'replaces a branch with a int64_not_zero? condition with a branch and int64_not_zero? test' do
      a = RubyJIT::IR::Node.new(:a)
      condition = RubyJIT::IR::Node.new(:int64_not_zero?)
      branch = RubyJIT::IR::Node.new(:branch)
      merge = RubyJIT::IR::Node.new(:merge)

      a.output_to :value, condition
      condition.output_to :value, branch, :condition
      branch.output_to :true, merge
      branch.output_to :false, merge
      @graph.start.output_to :control, branch
      merge.output_to :control, @graph.finish

      expect(@graph.find_node(:a)).to_not be_nil
      expect(@graph.find_node(:int64_not_zero?)).to_not be_nil
      expect(@graph.find_node(:branch)).to_not be_nil
      expect(@graph.find_node(:merge)).to_not be_nil

      @specialise_branches.run @graph

      expect(@graph.find_node(:a)).to_not be_nil
      expect(@graph.find_node(:branch)).to_not be_nil
      expect(@graph.find_node(:merge)).to_not be_nil

      expect(@graph.find_node(:int64_not_zero?)).to be_nil
      expect(@graph.find_node(:branch).props[:test]).to eq :int64_not_zero?
    end

  end

end
