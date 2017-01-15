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

require_relative '../fixtures'

describe RubyJIT::IR::Builder do

  before :each do
    @builder = RubyJIT::IR::Builder.new
  end

  describe '#graph' do

    it 'produces a graph' do
      expect(@builder.graph).to be_a(RubyJIT::IR::Graph)
    end

  end

  describe '#targets' do

    it 'returns an empty array for no instructions' do
      expect(@builder.targets([])).to be_empty
    end

    it 'reports the first instruction as a target' do
      expect(@builder.targets([[:self], [:return]])).to include(0)
    end

    it 'reports the target of a branch instruction as a target' do
      expect(@builder.targets([[:branch, 1], [:self], [:return]])).to include(1)
    end

    it 'reports the target of a branchif instruction as a target' do
      expect(@builder.targets([[:arg, 0], [:branchif, 4], [:self], [:return], [:self], [:return]])).to include(4)
    end

    it 'reports the instruction following a branchif instruction as a target' do
      expect(@builder.targets([[:arg, 0], [:branchif, 4], [:self], [:return], [:self], [:return]])).to include(2)
    end

    it 'does not report instructions that follow a branch as a target if nobody actually targets them' do
      expect(@builder.targets([[:arg, 0], [:branch, 4], [:self], [:return], [:self], [:return]])).to_not include(2)
    end

    it 'does not report other instructions as a target' do
      expect(@builder.targets([[:arg, 0], [:branch, 4], [:self], [:return], [:self], [:return]])).to_not include(3)
    end

    it 'only reports targets once' do
      expect(@builder.targets([[:branch, 0]])).to contain_exactly(0)
      expect(@builder.targets([[:arg, 0], [:branchif, 3], [:branch, 3], [:self], [:return]])).to contain_exactly(0, 2, 3)
    end

  end

  describe '#basic_blocks' do

    describe 'with a single basic block' do

      before :each do
        @insns = [
            [:push, 14],
            [:return]
        ]

        @basic_blocks = @builder.basic_blocks(@insns)
      end

      it 'returns one basic block' do
        expect(@basic_blocks.size).to eql 1
      end

      it 'returns one basic block containing all the instructions' do
        expect(@basic_blocks.keys.first).to eql 0
        expect(@basic_blocks.values.first.insns).to eql @insns
      end

    end

    describe 'with two basic blocks one after the other' do

      before :each do
        @insns = [
            [:arg, 0],
            [:branch, 2],

            [:push, 14],
            [:return]
        ]

        @basic_blocks = @builder.basic_blocks(@insns)
      end

      it 'returns two basic blocks' do
        expect(@basic_blocks.size).to eql 2
      end

      it 'returns two basic blocks that together contain all the instructions' do
        expect(@basic_blocks.values.flat_map(&:insns)).to match_array(@insns)
      end

      it 'returns two basic blocks in a chain' do
        expect(@basic_blocks.values.first.next).to contain_exactly(@basic_blocks.values.last.start)
        expect(@basic_blocks.values.last.prev).to contain_exactly(@basic_blocks.values.first.start)
      end

    end

    describe 'with four basic blocks, with a branch and then merge' do

      before :each do
        @insns = [
            [:arg, 0],
            [:branchif, 4],

            [:push, 14],
            [:branch, 5],

            [:push, 2],

            [:return]
        ]

        @basic_blocks = @builder.basic_blocks(@insns)
      end

      it 'returns four basic blocks' do
        expect(@basic_blocks.size).to eql 4
      end

      it 'returns one basic block that has two previous blocks' do
        expect(@basic_blocks.values.count { |b| b.prev.size == 2 }).to eql 1
      end

    end

  end

  describe '#basic_block_to_graph' do

    describe 'returns a graph fragment' do

      it do
        expect(@builder.basic_block_to_graph({}, [], [])).to be_a(RubyJIT::IR::Builder::GraphFragment)
      end

      it 'that has a region node' do
        region = @builder.basic_block_to_graph({}, [], []).region
        expect(region).to be_a(RubyJIT::IR::Node)
        expect(region.op).to eql :region
      end

      it 'that has a region node' do
        region = @builder.basic_block_to_graph({}, [], []).region
        expect(region).to be_a(RubyJIT::IR::Node)
        expect(region.op).to eql :region
      end

      it 'that has a last node' do
        fragment = @builder.basic_block_to_graph({}, [], [])
        expect(fragment.last_side_effect).to be_a(RubyJIT::IR::Node)
        expect(fragment.last_side_effect).to eql fragment.region
      end

      it 'that has a last side-effect node' do
        fragment = @builder.basic_block_to_graph({}, [], [])
        expect(fragment.last_side_effect).to be_a(RubyJIT::IR::Node)
        expect(fragment.last_side_effect).to eql fragment.region
      end

      it 'that has a list of the value of nodes at the end' do
        insns = [[:push, 14], [:store, :a]]
        fragment = @builder.basic_block_to_graph({}, [], insns)
        a = fragment.names_out[:a]
        expect(a.op).to eql :constant
        expect(a.props[:value]).to eql 14
      end

      it 'that has a stack of values at the end' do
        insns = [[:push, 14]]
        fragment = @builder.basic_block_to_graph({}, [], insns)
        expect(fragment.stack_out.size).to eql 1
        a = fragment.stack_out.first
        expect(a.op).to eql :constant
        expect(a.props[:value]).to eql 14
      end

    end

    describe 'correctly builds the single basic block in an add function' do

      before :each do
        @fragment = @builder.basic_block_to_graph({}, [], RubyJIT::Fixtures::ADD_BYTECODE_RUBYJIT)
        @graph = RubyJIT::IR::Graph.from_fragment(@fragment)
      end

      it 'with the region, trace and send nodes forming a control flow to the last_side_effect' do
        region = @graph.find_node(:region)
        trace_27 = @graph.find_node(:trace) { |t| t.props[:line] == 27 }
        trace_28 = @graph.find_node(:trace) { |t| t.props[:line] == 28 }
        send = @graph.find_node(:send)
        trace_29 = @graph.find_node(:trace) { |t| t.props[:line] == 29 }
        expect(region.outputs[:control]).to contain_exactly trace_27
        expect(trace_27.outputs[:control]).to contain_exactly trace_28
        expect(trace_28.outputs[:control]).to contain_exactly send
        expect(send.outputs[:control]).to contain_exactly trace_29
        expect(@fragment.last_side_effect).to eql trace_29
      end

      it 'with the pure nodes not sending control to any other nodes' do
        @graph.visit_nodes do |node|
          if [:arg, :store, :load].include?(node.op)
            expect(node.outputs[:control]).to be_nil
          end
        end
      end

      it 'with nodes that output control also taking it as input and not outputing it not taking it' do
        @graph.visit_nodes do |node|
          expect(node.has_control_input?).to eql node.has_control_output? unless [:start, :finish].include?(node.op)
        end
      end

    end

  end

end
