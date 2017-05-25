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

describe Rhizome::Passes::Inlining do

  before :each do
    @graph = Rhizome::IR::Graph.new
    @postbuild_pass = Rhizome::Passes::PostBuild.new
    @pass = Rhizome::Passes::Inlining.new
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

    describe 'branches a fixnum#+ send' do

      before :each do
        receiver = Rhizome::IR::Node.new(:constant, 14)
        operand = Rhizome::IR::Node.new(:constant, 2)
        send = Rhizome::IR::Node.new(:send, name: :+, argc: 1, kind: :fixnum)
        send.props[:profile] = Rhizome::Profile::SendProfile.new(0, Set.new([:fixnum]), [Set.new([:fixnum])])
        receiver.output_to :value, send, :receiver
        operand.output_to :value, send, :'arg(0)'
        @graph.start.output_to :control, send
        send.output_to :control, @graph.finish
      end

      it 'a primitive op and megamorphic send' do
        @pass.run @graph
        primitive = @graph.find_node(:fixnum_add)
        expect(primitive).to_not be_nil
        mega = @graph.find_node(:send)
        expect(mega).to_not be_nil
        expect(mega.props[:name]).to eql :+
        expect(mega.props[:megamorphic]).to be_truthy
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
