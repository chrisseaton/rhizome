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

require 'set'

require 'rhizomeruby'

describe Rhizome::Passes::InlineCaching do

  before :each do
    @graph = Rhizome::IR::Graph.new
    @postbuild_pass = Rhizome::Passes::PostBuild.new
    @pass = Rhizome::Passes::InlineCaching.new
  end

  describe '#run' do

    it 'does nothing to a send node with no profiling information' do
      receiver = Rhizome::IR::Node.new(:constant, 14)
      send = Rhizome::IR::Node.new(:send, name: :foo, argc: 0)
      receiver.output_to :value, send, :receiver
      @graph.start.output_to :control, send
      send.output_to :control, @graph.finish
      expect(@graph.find_node(:send).props[:kind]).to be_nil
      expect(@graph.find_node(:send).props[:megamorphic]).to be_nil
      @pass.run @graph
      expect(@graph.find_node(:send).props[:kind]).to be_nil
      expect(@graph.find_node(:send).props[:megamorphic]).to be_nil
    end

    describe 'branches a send node with profiling information' do

      before :each do
        receiver = Rhizome::IR::Node.new(:constant, 14)
        send = Rhizome::IR::Node.new(:send, name: :foo, argc: 0)
        send.props[:profile] = Rhizome::Profile::SendProfile.new(0, Set.new([:k]), [])
        receiver.output_to :value, send, :receiver
        @graph.start.output_to :control, send
        send.output_to :control, @graph.finish
      end

      it 'to create a branch and merge with two send nodes' do
        @pass.run @graph
        sends = []
        @graph.visit_nodes do |node|
          if node.op == :send
            sends.push node
            expect(node.props[:name]).to eql :foo
            expect(node.props[:megamorphic] || node.props[:kind] == :k).to be_truthy
          end
        end
        expect(sends.size).to eql 2
        expect(@graph.find_node(:branch)).to_not be_nil
        expect(@graph.find_node(:merge)).to_not be_nil
      end

    end

    describe 'with a fib function' do

      before :each do
        @interpreter = Rhizome::Interpreter.new
        @profile = Rhizome::Profile.new
        100.times do
          @interpreter.interpret Rhizome::Fixtures::FIB_BYTECODE_RHIZOME, Rhizome::Fixtures, [14, 2], @profile
        end
        @builder = Rhizome::IR::Builder.new
        @builder.build Rhizome::Fixtures::FIB_BYTECODE_RHIZOME, @profile
        @postbuild_pass.run @graph
        @graph = @builder.graph
      end

      it 'runs successfully' do
        @pass.run @graph
      end

    end

  end

end
