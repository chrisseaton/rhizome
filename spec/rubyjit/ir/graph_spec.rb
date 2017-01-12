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

describe RubyJIT::IR::Graph do

  describe '.new' do

    it 'creates a graph with start and finish nodes' do
      graph = RubyJIT::IR::Graph.new
      expect(graph.start).to be_a(RubyJIT::IR::Node)
      expect(graph.finish).to be_a(RubyJIT::IR::Node)
    end

    it 'creates a graph with the start node outputting control to the finish node' do
      graph = RubyJIT::IR::Graph.new
      expect(graph.start.outputs[:control]).to include(graph.finish)
    end

    it 'creates a graph with the finish node inputting control from the start node' do
      graph = RubyJIT::IR::Graph.new
      expect(graph.finish.inputs[:control]).to include(graph.start)
    end

  end


end
