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

describe RubyJIT::Passes::InsertSafepoints do

  before :each do
    @graph = RubyJIT::IR::Graph.new
    @insert_safepoints_pass = RubyJIT::Passes::InsertSafepoints.new
  end

  describe '#run' do

    it 'removes all trace nodes' do
      trace1 = RubyJIT::IR::Node.new(:trace, line: 1)
      trace2 = RubyJIT::IR::Node.new(:trace, line: 2)
      trace3 = RubyJIT::IR::Node.new(:trace, line: 3)
      @graph.start.output_to :control, trace1
      trace1.output_to :control, trace2
      trace2.output_to :control, trace3
      trace3.output_to :control, @graph.finish
      @insert_safepoints_pass.run @graph
      expect(@graph.find_nodes(:trace)).to be_empty
    end

    it 'leaves other nodes in place and connected' do
      trace1 = RubyJIT::IR::Node.new(:trace, line: 1)
      send1 = RubyJIT::IR::Node.new(:send)
      trace2 = RubyJIT::IR::Node.new(:trace, line: 2)
      send2 = RubyJIT::IR::Node.new(:send)
      trace3 = RubyJIT::IR::Node.new(:trace, line: 3)
      @graph.start.output_to :control, trace1
      trace1.output_to :control, send1
      send1.output_to :control, trace2
      trace2.output_to :control, send2
      send2.output_to :control, trace3
      trace3.output_to :control, @graph.finish
      @insert_safepoints_pass.run @graph
      expect(@graph.find_nodes(:trace)).to be_empty
      expect(@graph.find_nodes(:send).size).to eq 2
      expect(@graph.start.outputs_to?(:control, send1)).to be_truthy
    end

  end

end
