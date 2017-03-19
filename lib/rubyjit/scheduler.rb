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

        # The start node has sequence number zero.

        if node.op == :start
          node.props[:sequence] = 0
          next
        end

        # We're only interested in the control inputs to the node.

        control_input_nodes = node.inputs.control_edges.from_nodes

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

          tail.output_to :local_schedule, node
          tail = node
          scheduled.add node
        else
          to_schedule.push node
        end
      end
    end

    # Find all the nodes in a basic block, given the first node.

    def nodes_in_block(first_node)
      # We're going to do a depth-first search of the graph from the first
      # node, following control flow edges out, and global schedule eges in,
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

  end

end
