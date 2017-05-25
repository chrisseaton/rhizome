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

require_relative 'fixtures'

describe Rhizome::RegisterAllocator do

  before :each do
    @builder = Rhizome::IR::Builder.new
    @builder.build Rhizome::Fixtures::FIB_BYTECODE_RHIZOME
    @graph = @builder.graph
    @postbuild = Rhizome::Passes::PostBuild.new
    @postbuild.run @graph
    @passes_runner = Rhizome::Passes::Runner.new(
        Rhizome::Passes::DeadCode.new,
        Rhizome::Passes::NoChoicePhis.new
    )
    @passes_runner.run @graph
    @scheduler = Rhizome::Scheduler.new
    @scheduler.schedule @graph
    @registers = Rhizome::RegisterAllocator.new
  end

  describe '#allocate_infinite' do
    
    before :each do
      @registers.allocate_infinite @graph
    end

    it 'gives each node that produces a value a register annotation' do
      @graph.all_nodes.each do |node|
        if node.produces_value?
          expect(node.props.has_key?(:register)).to be_truthy
        end
      end
    end

    it 'only allocates registers' do
      @graph.all_nodes.each do |node|
        if node.produces_value?
          expect(node.props[:register].to_s).to start_with('r')
        end
      end
    end

    it 'does not give nodes that do not produce a value a register annotation' do
      @graph.all_nodes.each do |node|
        unless node.produces_value?
          expect(node.props.has_key?(:register)).to be_falsey
        end
      end
    end

    it 'only uses each register once' do
      registers = Set.new
      @graph.all_nodes.each do |node|
        if node.produces_value? && node.op != :move
          r = node.props[:register]
          expect(registers.include?(r)).to be_falsey
          registers.add r
        end
      end
    end

    it 'has all inputs to a phi node already having the same register' do
      @graph.all_nodes.each do |node|
        if node.op == :phi
          inputs = node.inputs.edges.select { |e| e.value? }.map { |e| e.from }
          registers = inputs.map { |i| i.props[:register] }
          registers.each do |r|
            expect(r).to eql registers.first
          end
        end
      end
    end

  end

  describe '#allocate_infinite_stack' do
    
    before :each do
      @registers.allocate_infinite_stack @graph
    end

    it 'gives each node that produces a value a register annotation' do
      @graph.all_nodes.each do |node|
        if node.produces_value?
          expect(node.props.has_key?(:register)).to be_truthy
        end
      end
    end

    it 'only allocates stack slots' do
      @graph.all_nodes.each do |node|
        if node.produces_value?
          expect(node.props[:register].to_s).to start_with('s')
        end
      end
    end

    it 'does not give nodes that do not produce a value a register annotation' do
      @graph.all_nodes.each do |node|
        unless node.produces_value?
          expect(node.props.has_key?(:register)).to be_falsey
        end
      end
    end

    it 'only uses each stack slot once' do
      slots = Set.new
      @graph.all_nodes.each do |node|
        if node.produces_value? && node.op != :move
          s = node.props[:register]
          expect(slots.include?(s)).to be_falsey
          slots.add s
        end
      end
    end

    it 'has all inputs to a phi node already having the same stack slot' do
      @graph.all_nodes.each do |node|
        if node.op == :phi
          inputs = node.inputs.edges.select { |e| e.value? }.map { |e| e.from }
          slots = inputs.map { |i| i.props[:register] }
          slots.each do |s|
            expect(s).to eql slots.first
          end
        end
      end
    end

  end

end
