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

end
