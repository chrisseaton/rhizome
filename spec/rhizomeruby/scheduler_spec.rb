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

require_relative 'fixtures'

describe Rhizome::Scheduler do

  before :each do
    @builder = Rhizome::IR::Builder.new
    @graph = @builder.graph
    @scheduler = Rhizome::Scheduler.new
  end

  describe '#partially_order' do

    describe 'can partially order an add function' do

      before :each do
        @builder.build Rhizome::Fixtures::ADD_BYTECODE_RHIZOME
        @scheduler.partially_order @graph
        @fixed = @graph.all_nodes.select(&:fixed?)
      end

      it 'with all fixed nodes having a sequence number' do
        expect(@fixed.all? { |n| n.props[:sequence] }).to be_truthy
      end

      it 'with all fixed nodes having a sequence number greater than all of their control inputs' do
        expect(@fixed.all? { |n| n.inputs.with_input_name(:control).from_nodes.all? { |i| n.props[:sequence] > i.props[:sequence] } }).to be_truthy
      end

    end

    describe 'can partially order a fib function' do

      before :each do
        @builder.build Rhizome::Fixtures::FIB_BYTECODE_RHIZOME
        @scheduler.partially_order @graph
        @fixed = @graph.all_nodes.select(&:fixed?)
      end

      it 'with all fixed nodes having a sequence number' do
        expect(@fixed.all? { |n| n.props[:sequence] }).to be_truthy
      end

      it 'with all fixed nodes having a sequence number greater than all of their control inputs' do
        expect(@fixed.all? { |n| n.inputs.with_input_name(:control).from_nodes.all? { |i| n.props[:sequence] > i.props[:sequence] } }).to be_truthy
      end

    end

  end

  describe '#global_schedule' do

    describe 'can globally schedule an add function' do

      before :each do
        @builder.build Rhizome::Fixtures::ADD_BYTECODE_RHIZOME
        @scheduler.partially_order @graph
        @scheduler.global_schedule @graph
      end

      it 'with all nodes being globally scheduled' do
        expect(@graph.all_nodes.all? { |n| @scheduler.globally_scheduled?(n) }).to be_truthy
      end

    end

    describe 'can globally schedule a fib function' do

      before :each do
        @builder.build Rhizome::Fixtures::FIB_BYTECODE_RHIZOME
        @scheduler.partially_order @graph
        @scheduler.global_schedule @graph
      end

      it 'with all nodes being globally scheduled' do
        expect(@graph.all_nodes.all? { |n| @scheduler.globally_scheduled?(n) }).to be_truthy
      end

    end

    describe '#local_schedule' do

      describe 'can locally schedule an add function' do

        before :each do
          @builder.build Rhizome::Fixtures::ADD_BYTECODE_RHIZOME
          @scheduler.partially_order @graph
          @scheduler.global_schedule @graph
          @scheduler.local_schedule @graph
        end

        it 'with all nodes being locally scheduled' do
          expect(@graph.all_nodes.all? { |n| @scheduler.locally_scheduled?(n) }).to be_truthy
        end

      end

      describe 'can locally schedule a fib function' do

        before :each do
          @builder.build Rhizome::Fixtures::FIB_BYTECODE_RHIZOME
          @scheduler.partially_order @graph
          @scheduler.global_schedule @graph
          @scheduler.local_schedule @graph
        end

        it 'with all nodes being locally scheduled' do
          expect(@graph.all_nodes.all? { |n| @scheduler.locally_scheduled?(n) }).to be_truthy
        end

      end

    end
    
  end

  describe '#linearize' do

    before :each do
      @builder.build Rhizome::Fixtures::FIB_BYTECODE_RHIZOME
      @postbuild = Rhizome::Passes::PostBuild.new
      @postbuild.run @graph
      @passes_runner = Rhizome::Passes::Runner.new(
          Rhizome::Passes::DeadCode.new,
          Rhizome::Passes::NoChoicePhis.new
      )
      @passes_runner.run @graph
      @scheduler.schedule @graph
      @register_allocator = Rhizome::RegisterAllocator.new
      @register_allocator.allocate_infinite @graph
      @blocks = @scheduler.linearize(@graph)
    end

    it 'produces an array of arrays of instructions' do
      expect(@blocks).to be_an(Array)
    end

    it 'has the block with the start instruction first' do
      expect(@blocks.first.first).to contain_exactly(:trace, 31)
    end

    it 'has the block with the finish instruction last' do
      expect(@blocks.last.first).to contain_exactly(:trace, 37)
    end

    it 'renames finish to return' do
      expect(@blocks.last.last).to start_with(:return)
    end

    it 'elides phi nodes' do
      expect(@blocks.flatten(1).map(&:first)).to_not include(:phi)
    end

    describe 'for a fib function' do

      it 'produces four basic blocks' do
        expect(@blocks.size).to eql 4
      end

    end

  end

end
