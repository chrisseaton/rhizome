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

require 'rubyjit'

require_relative 'fixtures'

describe RubyJIT::RegisterAllocator do

  before :each do
    @builder = RubyJIT::IR::Builder.new
    @builder.build RubyJIT::Fixtures::FIB_BYTECODE_RUBYJIT
    @graph = @builder.graph
    @postbuild = RubyJIT::Passes::PostBuild.new
    @postbuild.run @graph
    @passes_runner = RubyJIT::Passes::Runner.new(
        RubyJIT::Passes::DeadCode.new,
        RubyJIT::Passes::NoChoicePhis.new
    )
    @passes_runner.run @graph
    @scheduler = RubyJIT::Scheduler.new
    @scheduler.schedule @graph
    @registers = RubyJIT::RegisterAllocator.new
    @registers.allocate_infinite @graph
  end

  describe '#allocate_infinite' do

    it 'gives each node that produces a value a register annotation' do
      @graph.all_nodes.each do |node|
        if node.produces_value?
          expect(node.props.has_key?(:register)).to be_truthy
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

end
