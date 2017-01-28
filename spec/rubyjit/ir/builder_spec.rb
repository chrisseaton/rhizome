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

module RubyJIT::Fixtures::Builder

  def self.control_flows(spec, graph, last_control, *flow)
    flow = flow.map { |n| resolve(graph, n) }

    1.upto(flow.size - 1).each do |i|
      n0 = flow[i - 1]
      n1 = flow[i]
      spec.expect(n0.outputs.with_output_name(:control).to_nodes).to spec.contain_exactly n1
      spec.expect(n1.inputs.with_input_name(:control).from_nodes).to spec.contain_exactly n0
    end

    spec.expect(last_control).to spec.eql flow.last
  end

  def self.data_flows(spec, graph, *flow)
    flow = flow.dup
    nodes = {}

    until flow.empty?
      f = flow.shift
      if f.is_a?(Symbol)
        nodes[f] = resolve(graph, flow.shift)
      elsif f.is_a?(Array)
        from, from_name, to, to_name = f
        from = nodes[from] || resolve(graph, from)
        to = nodes[to] || resolve(graph, to)
        spec.expect(from.outputs.with_output_name(from_name).to_nodes).to spec.include to
        spec.expect(to.inputs.with_input_name(to_name).from_nodes).to spec.include from
      else
        raise 'unexpected data flow declaration'
      end
    end
  end

  def self.resolve(graph, description)
    if description.is_a?(Symbol)
      graph.find_node(description)
    elsif description.is_a?(Proc)
      graph.find_node(&description)
    else
      raise 'unexpected node description'
    end
  end

  def self.pure_nodes_have_no_control(spec, graph)
    graph.visit_nodes do |node|
      if [:arg, :store, :load].include?(node.op)
        spec.expect(node.outputs.with_output_name(:control)).to spec.be_empty
      end
    end
  end

  def self.nodes_output_control_iff_input_control(spec, graph)
    graph.visit_nodes do |node|
      spec.expect(node.has_control_input?).to spec.eql node.has_control_output? unless [:start, :finish].include?(node.op)
    end
  end

end

describe RubyJIT::IR::Builder do

  before :each do
    @builder = RubyJIT::IR::Builder.new
  end

  describe '#graph' do

    it 'produces a graph' do
      expect(@builder.graph).to be_a(RubyJIT::IR::Graph)
    end

  end

  describe '#build' do

    describe 'builds an add function' do

      before :each do
        @builder.build(RubyJIT::Fixtures::ADD_BYTECODE_RUBYJIT)
        @graph = @builder.graph
      end

      it 'with a single send node' do
        expect(@graph.all_nodes.count { |n| n.op == :send }).to eql 1
      end

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
        expect(@builder.basic_block_to_graph([])).to be_a(RubyJIT::IR::Builder::GraphFragment)
      end

      it 'that has a region node' do
        region = @builder.basic_block_to_graph([]).region
        expect(region).to be_a(RubyJIT::IR::Node)
        expect(region.op).to eql :region
      end

      it 'that has a region node' do
        region = @builder.basic_block_to_graph([]).region
        expect(region).to be_a(RubyJIT::IR::Node)
        expect(region.op).to eql :region
      end

      it 'that has a last node' do
        fragment = @builder.basic_block_to_graph([])
        expect(fragment.last_control).to be_a(RubyJIT::IR::Node)
        expect(fragment.last_control).to eql fragment.region
      end

      it 'that has a last side-effect node' do
        fragment = @builder.basic_block_to_graph([])
        expect(fragment.last_control).to be_a(RubyJIT::IR::Node)
        expect(fragment.last_control).to eql fragment.region
      end

      it 'that has a list of the value of nodes at the end' do
        insns = [[:push, 14], [:store, :a]]
        fragment = @builder.basic_block_to_graph(insns)
        a = fragment.names_out[:a]
        expect(a.op).to eql :constant
        expect(a.props[:value]).to eql 14
      end

      it 'that has a stack of values at the end' do
        insns = [[:push, 14]]
        fragment = @builder.basic_block_to_graph(insns)
        expect(fragment.stack_out.size).to eql 1
        a = fragment.stack_out.first
        expect(a.op).to eql :constant
        expect(a.props[:value]).to eql 14
      end

    end

    describe 'correctly builds the single basic block in an add function' do

      before :each do
        @fragment = @builder.basic_block_to_graph(RubyJIT::Fixtures::ADD_BYTECODE_RUBYJIT)
        @graph = RubyJIT::IR::Graph.from_fragment(@fragment)
      end

      it 'not requiring any names' do
        expect(@fragment.names_in).to be_empty
      end

      it 'not requiring anything from the stack' do
        expect(@fragment.stack_in).to be_empty
      end

      it 'with the region, trace and send nodes forming a control flow to the last_control' do
        RubyJIT::Fixtures::Builder.control_flows(
            self, @graph, @fragment.last_control,
            :region,
            ->(n) { n.op == :trace && n.props[:line] == 27 },
            ->(n) { n.op == :trace && n.props[:line] == 28 },
            :send,
            ->(n) { n.op == :trace && n.props[:line] == 29 }
        )
      end

      it 'with data flowing from the args to the send and then to the finish' do
        RubyJIT::Fixtures::Builder.data_flows(
            self, @graph,
            :a, ->(n) { n.op == :arg && n.props[:n] == 0 },
            :b, ->(n) { n.op == :arg && n.props[:n] == 1 },
            :add, :send,
            [:a, :value, :add, :receiver],
            [:b, :value, :add, :args],
            [:add, :value, :finish, :value]
        )
      end

      it 'with the pure nodes not sending control to any other nodes' do
        RubyJIT::Fixtures::Builder.pure_nodes_have_no_control self, @graph
      end

      it 'with nodes that output control also taking it as input and not outputing it not taking it' do
        RubyJIT::Fixtures::Builder.nodes_output_control_iff_input_control self, @graph
      end

      it 'with a and b as names' do
        expect(@fragment.names_out.keys).to contain_exactly :a, :b
      end

      it 'with the return value on the stack' do
        expect(@fragment.stack_out.size).to eql 1
      end

    end

    describe 'correctly builds the first basic block in a fib function' do

      before :each do
        basic_blocks = @builder.basic_blocks(RubyJIT::Fixtures::FIB_BYTECODE_RUBYJIT)
        block = basic_blocks.values[0]
        @fragment = @builder.basic_block_to_graph(block.insns)
        @graph = RubyJIT::IR::Graph.from_fragment(@fragment)
      end

      it 'not requiring any names' do
        expect(@fragment.names_in).to be_empty
      end

      it 'not requiring anything from the stack' do
        expect(@fragment.stack_in).to be_empty
      end

      it 'with the region, trace and send nodes forming a control flow to the last_control' do
        RubyJIT::Fixtures::Builder.control_flows(
            self, @graph, @fragment.last_control,
            :region,
            ->(n) { n.op == :trace && n.props[:line] == 31 },
            ->(n) { n.op == :trace && n.props[:line] == 32 },
            :send,
            :branchif
        )
      end

      it 'with data flowing from the arg and constant to the send, the not and the branchif' do
        RubyJIT::Fixtures::Builder.data_flows(
            self, @graph,
            [:arg, :value, :send, :receiver],
            [:constant, :value, :send, :args],
            [:send, :value, :not, :value],
            [:not, :value, :branchif, :condition]
        )
      end

      it 'with the pure nodes not sending control to any other nodes' do
        RubyJIT::Fixtures::Builder.pure_nodes_have_no_control self, @graph
      end

      it 'with nodes that output control also taking it as input and not outputing it not taking it' do
        RubyJIT::Fixtures::Builder.nodes_output_control_iff_input_control self, @graph
      end

      it 'with n as a name' do
        expect(@fragment.names_out.keys).to contain_exactly :n
      end

      it 'with an empty stack' do
        expect(@fragment.stack_out).to be_empty
      end

    end

    describe 'correctly builds the second basic block in a fib function' do

      before :each do
        basic_blocks = @builder.basic_blocks(RubyJIT::Fixtures::FIB_BYTECODE_RUBYJIT)
        block = basic_blocks.values[1]
        @fragment = @builder.basic_block_to_graph(block.insns)
        @graph = RubyJIT::IR::Graph.from_fragment(@fragment)
      end

      it 'requiring a name' do
        expect(@fragment.names_in.size).to eql 1
        expect(@fragment.names_in.keys.first).to eql :n
        expect(@fragment.names_in.values.first.op).to eql :input
      end

      it 'not requiring anything from the stack' do
        expect(@fragment.stack_in).to be_empty
      end

      it 'with the region and trace nodes forming a control flow to the last_control' do
        RubyJIT::Fixtures::Builder.control_flows(
            self, @graph, @fragment.last_control,
            :region,
            ->(n) { n.op == :trace && n.props[:line] == 33 },
            :branch
        )
      end

      it 'with not data flowing because the value is on the stack' do
        RubyJIT::Fixtures::Builder.data_flows(
            self, @graph
        )
      end

      it 'with the pure nodes not sending control to any other nodes' do
        RubyJIT::Fixtures::Builder.pure_nodes_have_no_control self, @graph
      end

      it 'with nodes that output control also taking it as input and not outputing it not taking it' do
        RubyJIT::Fixtures::Builder.nodes_output_control_iff_input_control self, @graph
      end

      it 'with n as a name' do
        expect(@fragment.names_out.keys).to contain_exactly :n
      end

      it 'with the argument value on the stack' do
        expect(@fragment.stack_out.size).to eql 1
        expect(@fragment.stack_out.first).to eql @fragment.names_in.values.first
      end

    end

    describe 'correctly builds the third basic block in a fib function' do

      before :each do
        basic_blocks = @builder.basic_blocks(RubyJIT::Fixtures::FIB_BYTECODE_RUBYJIT)
        block = basic_blocks.values[2]
        @fragment = @builder.basic_block_to_graph(block.insns)
        @graph = RubyJIT::IR::Graph.from_fragment(@fragment)
      end

      it 'requiring a name' do
        expect(@fragment.names_in.size).to eql 1
        expect(@fragment.names_in.keys.first).to eql :n
        expect(@fragment.names_in.values.first.op).to eql :input
      end

      it 'not requiring anything from the stack' do
        expect(@fragment.stack_in).to be_empty
      end

      it 'with the region, trace and send nodes forming a control flow to the last_control' do
        RubyJIT::Fixtures::Builder.control_flows(
            self, @graph, @fragment.last_control,
            :region,
            ->(n) { n.op == :trace && n.props[:line] == 35 },
            ->(n) { n.op == :send && n.props[:name] == :- && n.inputs.with_input_name(:args).from_nodes.first.props[:value] == 1 },
            ->(n) { n.op == :send && n.props[:name] == :fib && n.inputs.with_input_name(:args).from_nodes.first.inputs.with_input_name(:args).from_nodes.first.props[:value] == 1 },
            ->(n) { n.op == :send && n.props[:name] == :- && n.inputs.with_input_name(:args).from_nodes.first.props[:value] == 2 },
            ->(n) { n.op == :send && n.props[:name] == :fib && n.inputs.with_input_name(:args).from_nodes.first.inputs.with_input_name(:args).from_nodes.first.props[:value] == 2 },
            ->(n) { n.op == :send && n.props[:name] == :+ }
        )
      end

      it 'with data flowing through the expression' do
        RubyJIT::Fixtures::Builder.data_flows(
            self, @graph,
            :const_one, ->(n) { n.op == :constant && n.props[:value] == 1 },
            :const_two, ->(n) { n.op == :constant && n.props[:value] == 2 },
            :sub_one, ->(n) { n.op == :send && n.props[:name] == :- && n.inputs.with_input_name(:args).from_nodes.first.props[:value] == 1 },
            :fib_one, ->(n) { n.op == :send && n.props[:name] == :fib && n.inputs.with_input_name(:args).from_nodes.first.inputs.with_input_name(:args).from_nodes.first.props[:value] == 1 },
            :sub_two, ->(n) { n.op == :send && n.props[:name] == :- && n.inputs.with_input_name(:args).from_nodes.first.props[:value] == 2 },
            :fib_two, ->(n) { n.op == :send && n.props[:name] == :fib && n.inputs.with_input_name(:args).from_nodes.first.inputs.with_input_name(:args).from_nodes.first.props[:value] == 2 },
            :add, ->(n) { n.op == :send && n.props[:name] == :+ },
            [:input, :value, :sub_one, :receiver],
            [:const_one, :value, :sub_one, :args],
            [:input, :value, :sub_two, :receiver],
            [:const_two, :value, :sub_two, :args],
            [:sub_one, :value, :fib_one, :args],
            [:sub_two, :value, :fib_two, :args],
            [:fib_one, :value, :add, :receiver],
            [:fib_two, :value, :add, :args],
            [:add, :value, :finish, :value]
        )
      end

      it 'with the pure nodes not sending control to any other nodes' do
        RubyJIT::Fixtures::Builder.pure_nodes_have_no_control self, @graph
      end

      it 'with nodes that output control also taking it as input and not outputing it not taking it' do
        RubyJIT::Fixtures::Builder.nodes_output_control_iff_input_control self, @graph
      end

      it 'with n as a name' do
        expect(@fragment.names_out.keys).to contain_exactly :n
      end

      it 'with the value from the send on the stack' do
        expect(@fragment.stack_out.size).to eql 1
        expect(@fragment.stack_out.first.op).to eql :send
      end

    end

    describe 'correctly builds the fourth basic block in a fib function' do

      before :each do
        basic_blocks = @builder.basic_blocks(RubyJIT::Fixtures::FIB_BYTECODE_RUBYJIT)
        block = basic_blocks.values[3]
        @fragment = @builder.basic_block_to_graph(block.insns)
        @graph = RubyJIT::IR::Graph.from_fragment(@fragment)
      end

      it 'not requiring any names' do
        expect(@fragment.names_in).to be_empty
      end

      it 'requiring one value from the stack' do
        expect(@fragment.stack_in.size).to eql 1
        expect(@fragment.stack_in.first.op).to eql :input
      end

      it 'with the region, trace, and return nodes forming a control flow to the last_control' do
        RubyJIT::Fixtures::Builder.control_flows(
            self, @graph, @fragment.last_control,
            :region,
            ->(n) { n.op == :trace && n.props[:line] == 37 }
        )
      end

      it 'with data flowing from the value on the stack to the finish' do
        RubyJIT::Fixtures::Builder.data_flows(
            self, @graph,
            [:input, :value, :finish, :value]
        )
      end

      it 'with the pure nodes not sending control to any other nodes' do
        RubyJIT::Fixtures::Builder.pure_nodes_have_no_control self, @graph
      end

      it 'with nodes that output control also taking it as input and not outputing it not taking it' do
        RubyJIT::Fixtures::Builder.nodes_output_control_iff_input_control self, @graph
      end

      it 'with no names' do
        expect(@fragment.names_out).to be_empty
      end

      it 'with the returned value on the stack' do
        expect(@fragment.stack_out.size).to eql 1
        expect(@fragment.stack_out.first.op).to eql :input
      end

    end

  end

end
