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

describe RubyJIT::Backend::General::ExpandCalls do

  before :each do
    @graph = RubyJIT::IR::Graph.new
    @expand_calls = RubyJIT::Backend::General::ExpandCalls.new
  end

  describe '#run' do

    it 'replaces send with call_managed' do
      receiver = RubyJIT::IR::Node.new(:receiver)
      arg = RubyJIT::IR::Node.new(:arg)
      send = RubyJIT::IR::Node.new(:send, name: :foo, argc: 1)
      @graph.start.output_to :value, send
      receiver.output_to :value, send, :receiver
      arg.output_to :value, send, :'arg(0)'
      send.output_to :value, @graph.finish
      @graph.start.output_to :value, @graph.finish

      expect(@graph.find_node(:receiver)).to_not be_nil
      expect(@graph.find_node(:arg)).to_not be_nil
      expect(@graph.find_node(:send)).to_not be_nil

      @expand_calls.run @graph

      expect(@graph.find_node(:receiver)).to_not be_nil
      expect(@graph.find_node(:arg)).to_not be_nil
      expect(@graph.find_node(:send)).to be_nil
      expect(@graph.find_node(:call_managed)).to_not be_nil

      name = @graph.find_node(:constant)
      expect(name).to_not be_nil
      expect(name.props[:value]).to  eq :foo
    end

  end

end
