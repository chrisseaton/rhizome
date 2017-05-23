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

module RubyJIT

  # The scheduler takes a program in intermediate representation and works out
  # an order in which to run the program.

  class Scheduler

    # Schedule a graph.

    def schedule(graph)
      partially_order graph
      global_schedule graph
      local_schedule graph
    end

    # Partially order the fixed nodes in a graph, so that each has a sequence
    # number which can be compared. If one node must come before another then
    # it will have a lower sequence number.

    def partially_order(graph)
      # Create a work list of the fixed nodes.

      to_sequence = graph.all_nodes.select(&:fixed?)

      # Keep going until the work list is empty.

      until to_sequence.empty?
        node = to_sequence.shift

        # We're only interested in the control inputs to the node.

        control_input_nodes = node.inputs.control_edges.from_nodes

        # Nodes with no control input (such as start but possibly others) have sequence number zero.

        if control_input_nodes.empty?
          node.props[:sequence] = 0
          next
        end

        # If all control inputs have been given a sequence, we can give this
        # node as at least one greater than all of those.

        if control_input_nodes.all? { |i| i.props[:sequence] }
          node.props[:sequence] = control_input_nodes.map { |i| i.props[:sequence] }.max + 1
          next
        end

        # If all the control inputs haven't been given a sequence number yet
        # then put it back on the work list and come back to it later.

        to_sequence.push node
      end
    end

    # Globally schedule a graph, meaning to anchor all floating nodes to a
    # fixed node. All fixed nodes are part of a basic block, so globally
    # scheduling also puts all floating nodes into a basic block.

    def global_schedule(graph)
      # Create a work list of the floating nodes.

      to_schedule = graph.all_nodes.select(&:floating?)

      # Keep going until the work list is empty.

      until to_schedule.empty?
        node = to_schedule.shift

        # Are we ready to schedule this node?

        if ready_to_schedule?(node)
          # Find candidates to anchor this node to.

          candidates = schedule_candidates(graph, node)

          # If there aren't any then we're stuck!

          raise 'stuck' if candidates.empty?

          # Sort the candidates and take the first one to get the best.

          best_candidate = sort_candidates(candidates).first

          # Add a global schedule edge.

          node.output_to :global_schedule, best_candidate
        else
          # If we aren't ready to schedule this node, try it again later.

          to_schedule.push node
        end
      end
    end

    # A node is ready to be globally scheduled if all outputs have themselves
    # been globally scheduled.

    def ready_to_schedule?(node)
      # Ready to globally schedule

      node.outputs.to_nodes.all? do |i|
        globally_scheduled?(i)
      end
    end

    # A node is globally scheduled if it was fixed anyway or we've scheduled it.

    def globally_scheduled?(node)
      node.fixed? || node.outputs.output_names.include?(:global_schedule)
    end

    # Find all possible nodes we could anchor a floating node to to globally
    # schedule it.

    def schedule_candidates(graph, node)
      if node.outputs.size == 1
        # If a node has just one output then that's the only candidate.

        [node.outputs.to_nodes.first]
      else
        # Otherwise, consider all the nodes in the graph (yes this is
        # quadratic).

        graph.all_nodes.select do |candidate|
          # The start node is never a candidate because we're going to schedule
          # before the candidate, and we can't schedule before the start node.

          if candidate.op != :start
            # We only consider globally scheduled nodes as candidates.

            if globally_scheduled?(candidate)
              # Is there a control-flow path from all the inputs of the node to this candidate?

              from_all_inputs = node.inputs.from_nodes.all? { |i| !globally_scheduled?(i) || path_from_to(i, candidate) }

              # Is there a control-flow path from this candidate to all the outputs of this node?

              to_all_outputs = node.outputs.to_nodes.all? { |o| !globally_scheduled?(o) || path_from_to(candidate, o) }

              # Both conditions need to be true for this candidate to be valid.

              from_all_inputs && to_all_outputs
            end
          end
        end
      end
    end

    # Sort a list of candidates in decreasing sequence number.

    def sort_candidates(candidates)
      candidates.sort_by { |candidate|
        anchor = fixed_anchor(candidate)
        sequence = anchor.props[:sequence]
        raise unless sequence
        sequence
      }.reverse
    end

    # Is there a control-flow path that we can follow from one node
    # to another.

    def path_from_to(a, b)
      # Work with the fixed anchors of the nodes because that's where the
      # control flow is fixed to.

      a = fixed_anchor(a)
      b = fixed_anchor(b)

      # We're going to do a depth-first search starting with the first node
      # and we're going to see if we can find the second node. We keep a stack
      # of nodes that we need to visit, and a set of nodes that we've already
      # visited so that we don't visit nodes more than once. We pop a node
      # off the stack, return if it was the node we were looking for, or move
      # on if we've already visited it, if not we push the outputs of the node
      # to visit next.

      worklist = [a]
      considered = Set.new
      until worklist.empty?
        node = worklist.pop
        return true if node == b
        if considered.add?(node)
          worklist.push *node.outputs.control_edges.to_nodes
        end
      end

      # We traversed the whole graph accessible from the first node and didn't
      # find the second one.

      false
    end

    # Give the node that a node is attached to in the global schedule.

    def fixed_anchor(node)
      raise unless globally_scheduled?(node)

      if node.fixed?
        # A fixed node is anchored to itself.
        node
      else
        # Otherwise we anchored using an output to another node.
        anchor = node.outputs.with_output_name(:global_schedule).to_nodes.first
        raise unless anchor
        fixed_anchor(anchor)
      end
    end

    # Locally schedule a graph, which means within each basic block decide a
    # single order to run the nodes, which no ambiguity left.

    def local_schedule(graph)
      # Find all basic blocks and locally schedule them.

      graph.all_nodes.each do |node|
        if node.begins_block?
          locally_schedule_block node
        end
      end
    end

    # Locally schedule within each basic block.

    def locally_schedule_block(first_node)
      # Find all the nodes in this basic block.

      in_block = Set.new(nodes_in_block(first_node))

      # Back up a second... our first node could be a fixed node, which
      # actually has input values. Such as a branch with a condition.
      # The nodes involved in that condition actually need to come first.

      first_node = first_in_block(first_node, in_block)

      # Create a work list of nodes to schedule and a set of nodes
      # already scheduled.

      to_schedule = in_block.to_a
      scheduled = Set.new

      # The first node in the basic block is already scheduled first.

      to_schedule.delete first_node
      scheduled.add first_node

      # The tail is the last node we scheduled.

      tail = first_node

      until to_schedule.empty?
        node = to_schedule.shift

        # We are ready to locally schedule if all inputs that are in this
        # block have themselves already been scheduled.

        if node.inputs.from_nodes.all? { |i| !in_block.include?(i) || scheduled.include?(i) }
          # Add a local schedule edge from the previous last node to this one,
          # which then becomes the last node.
          raise if tail.inputs.from_nodes.include? node
          tail.output_to :local_schedule, node
          tail = node
          scheduled.add node
        else
          to_schedule.push node
        end
      end
    end

    # We've got a problem with our IR design here. We expect some fixed
    # control flow node to be the start of the basic block. In the case
    # of at least some branches, they can have input that needs to run
    # first, but our system just isn't designed for anything except a
    # control flow node to need to run first. This fix-up method walks
    # back from the fixed node to see if actually there is an input that
    # needs to run first. Not a great solution.

    def first_in_block(first, nodes)
      first.inputs.from_nodes.each do |n|
        if nodes.include?(n)
          return first_in_block(n, nodes)
        end
      end
      first
    end

    # Find all the nodes in a basic block, given the first node.

    def nodes_in_block(first_node)
      # We're going to do a depth-first search of the graph from the first
      # node, following control flow edges out, and global schedule edges in,
      # and stopping when we find a node that ends a basic block such as a
      # branch.

      worklist = [first_node]
      block = Set.new

      until worklist.empty?
        node = worklist.pop

        if block.add?(node)
          # We need to visit nodes that are anchored to this one.

          node.inputs.edges.each do |i|
            if i.input_name == :global_schedule
              worklist.push i.from
            end
          end

          # If this node isn't a branch, and it's either the first node or it
          # isn't a merge, visit the nodes that follow it in control flow.

          if node.op != :branch && (node == first_node || node.op != :merge)
            node.outputs.edges.each do |o|
              if o.control?
                if !(node.op == :start && o.to.op == :finish)
                  worklist.push o.to
                end
              end
            end
          end
        end
      end

      block.to_a
    end

    # A node is locally scheduled if it's fixed or we have locally scheduled it.

    def locally_scheduled?(node)
      node.fixed? || node.outputs.output_names.include?(:local_schedule)
    end

    # Linearize a graph into a single linear sequence of operations with jumps
    # and branches.

    def linearize(graph)
      # The basic blocks.
      blocks = []
      
      # Details of the basic block that contain the finish operation which
      # won't be added to the list of basic blocks until the end.
      first_node_last_block = nil
      last_block = nil
      
      # Two maps that help us map between nodes and the names of the blocks
      # that they go into, and the merge instruction indicies and the blocks
      # they're coming from.
      first_node_to_block_index = {}
      merge_index_to_first_node = {}

      # Look at each node that begins a basic block.

      basic_block_starters = graph.all_nodes.select { |n| n.begins_block? }

      last_basic_block_starter = basic_block_starters.select { |s| nodes_in_block(s).any? { |n| n.op == :finish } }.first

      basic_block_starters.delete last_basic_block_starter
      basic_block_starters.push last_basic_block_starter

      basic_block_starters.each do |node|
        original_first_node = node
        node = first_in_block(original_first_node, nodes_in_block(original_first_node))
        first_node = node

        # We're going to create an array of operations for this basic
        # block.

        block = []
        next_to_last_control = nil

        # Follow the local sequence.

        begin
          # We don't want to include operations that are just there to form
          # branches or anchor points in the graph such as start and merge.

          unless [:start, :merge].include?(node.op)
            op = node.op

            # We rename finish to return to match the switch from the
            # declarative style of the graph to the imperative style
            # of the list of operations.
            op = :return if op == :finish

            # The instruction begins with the operation.
            insn = [op]

            # Then any constant values or similar.
            [:line, :n, :value].each do |p|
              insn.push node.props[p] if node.props.has_key?(p)
            end

            # Then any input registers.
            node.inputs.with_input_name(:value).from_nodes.each do |input_values|
              insn.push input_values.props[:register]
            end

            # Phi instructions need pairs of source registers with the blocks they came from.
            if node.op == :phi
              node.inputs.edges.each do |input|
                if input.input_name =~ /^value\((.+)\)$/
                  n = $1.to_i
                  insn.push n
                  insn.push input.from.props[:register]
                end
              end
              # Elide phi instructions if register allocation has run correctly and values are
              # already in the correct registers.
              insn = nil if insn.drop(2).select.with_index{ |_,i| i.even? }.uniq.size == 1
            end

            # Send instructions and lowered equivalents need the arguments.
            if [:send, :call_managed, :int64_add, :int64_and, :int64_shift_left, :int64_shift_right].include?(node.op)
              insn.push node.inputs.with_input_name(:receiver).from_nodes.first.props[:register]

              if node.op == :send
                insn.push node.props[:name]
              elsif node.op == :call_managed
                insn.push node.inputs.with_input_name(:name).from_nodes.first.props[:register]
              end

              node.props[:argc].times do |n|
                insn.push node.inputs.with_input_name(:"arg(#{n})").from_nodes.first.props[:register]
              end
            end

            # Then the target register if the instruction has one.
            insn.push node.props[:register] if insn && (node.produces_value? || node.op == :move)

            # If it's a branch then the target basic blocks and the test.
            if node.op == :branch
              insn.push node.inputs.with_input_name(:condition).from_node.props[:register]

              [:true, :false].each do |branch|
                target = node.outputs.with_output_name(branch).to_nodes.first
                raise unless target
                insn.push target
              end

              if node.props[:test]
                insn.push node.props[:test]
              end
            end
            
            # Guards are like branches, but only have one side.
            if node.op == :guard
              insn.push node.inputs.with_input_name(:condition).from_node.props[:register]
              
              if node.props[:test]
                insn.push node.props[:test]
              end
            end

            # Kind instructions need the kind.
            if node.op == :kind_is?
              insn.push node.props[:kind]
            end
  
            # Frame states need the instructions, the ip, and to know where all values are.
            if node.op == :frame_state
              insn.push node.props[:insns]
              insn.push node.props[:ip]
              insn.push node.inputs.with_input_name(:receiver).from_node.props[:register]

              insn.push node.inputs.edges.select { |e| e.input_name.to_s.start_with?('arg(') }.map { |e|
                /arg\((\d+)\)/ =~ e.input_name.to_s
                [$1.to_i, e.from.props[:register]]
              }.sort_by { |pair| pair.first }.map { |pair| pair.last }
            end

            # Add the instruction to the block.
            block.push insn if insn
          end

          next_to_last_control = node if node.has_control_output?

          # Follow the local schedule edge to the next node.
          node = node.outputs.with_output_name(:local_schedule).to_nodes.first
        end while node && node.op != :merge

        # If the last node is a merge, we need to remember which merge index this is.

        if node && node.op == :merge
          next_to_last_control.outputs.with_output_name(:control).edges.first.input_name =~ /^control\((.+)\)$/
          n = $1.to_i
          merge_index_to_first_node[n] = first_node
        end

        # Add a jump instruction if this block was going to just flow into the next
        # - we'll remove it later if the block followed it anyway and we can just
        # fallthrough.

        unless [:return, :branch].include?(block.last.first)
          begin
            block.push [:jump, next_to_last_control.outputs.with_output_name(:control).to_node]
          rescue
            block.push [:jump, :broken]
          end
        end

        first_node_to_block_index[original_first_node] = blocks.size
        first_node_to_block_index[first_node] = blocks.size
        blocks.push block
      end

      # Record the number that this basic block has and then add it to the list of basic blocks.

      first_node_to_block_index[first_node_last_block] = blocks.size

      # Go back through the basic blocks and update some references that were to things that
      # hadn't been decided yet.

      blocks.each do |block|
        block.each do |insn|
          insn.map! do |e|
            # If part of an instruction references a basic block, turn that into the index of
            # the basic block instead.

            if e.is_a?(IR::Node)
              :"block#{first_node_to_block_index[e]}"
            else
              e
            end
          end
        end
      end

      # Go back through the basic blocks and change how the branch instructions out of them
      # work.

      blocks.each_with_index do |block, n|
        next_block = :"block#{n + 1}"
        last = block.last

        if last == [:jump, next_block]
          # A jump that just goes to the next block can be removed and left to fall through.
          block.pop
        elsif last.first == :branch && last[3] == next_block
          # A branch where the else goes to the next block can branch only when true.
          block.pop
          block.push [:branch_if, last[1], last[2], *last.drop(4)]
        elsif last.first == :branch && last[2] == next_block
          # A branch where the if goes to the next block can branch only unless true.
          block.pop
          test = last.drop(4)
          block.push [:branch_unless, last[1], last[3], *test]
        elsif last.first == :branch
          # A branch that doesn't go to the next block at all can be a branch if true
          # and then fallthrough to a new jump instruction.
          block.pop
          block.push [:branch_if, last[1], last[2], *last.drop(4)]
          block.push [:jump, last[3]]
        end
      end

      blocks
    end

  end

end
