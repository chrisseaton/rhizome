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

describe RubyJIT::Passes::PostBuild do

  before :each do
    @graph = RubyJIT::IR::Graph.new
    @pass = RubyJIT::Passes::PostBuild.new
  end

  describe '#run' do

    it 'removes jump nodes' do
      jump = RubyJIT::IR::Node.new(:jump)
      @graph.start.output_to :control, jump
      jump.output_to :control, @graph.finish
      expect(@graph.contains?(:jump)).to be_truthy
      @pass.run @graph
      expect(@graph.contains?(:jump)).to be_falsey
    end

    it 'removes connector nodes' do
      connector = RubyJIT::IR::Node.new(:connector)
      @graph.start.output_to :control, connector
      connector.output_to :control, @graph.finish
      expect(@graph.contains?(:connector)).to be_truthy
      @pass.run @graph
      expect(@graph.contains?(:connector)).to be_falsey
    end

    it 'removes merge nodes that do not merge' do
      merge = RubyJIT::IR::Node.new(:merge)
      @graph.start.output_to :control, merge
      merge.output_to :control, @graph.finish
      expect(@graph.contains?(:merge)).to be_truthy
      @pass.run @graph
      expect(@graph.contains?(:merge)).to be_falsey
    end

    it 'does not remove merge nodes that merge' do
      a = RubyJIT::IR::Node.new(:merge)
      @graph.start.output_to :control, a
      b = RubyJIT::IR::Node.new(:merge)
      @graph.start.output_to :control, b
      merge = RubyJIT::IR::Node.new(:merge)
      a.output_to :control, merge
      b.output_to :control, merge
      expect(@graph.contains? { |n| n == merge }).to be_truthy
      @pass.run @graph
      expect(@graph.contains? { |n| n == merge }).to be_truthy
    end

  end

end
