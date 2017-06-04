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

module Rhizome

  # The register allocator annotates nodes in a graph which produce a value
  # with either the name of a register or a memory location in which the
  # value will be stored.

  class RegisterAllocator

    # Allocate registers using the linear scan algorithm.

    def allocate(graph)
      # Give all nodes a linear sequence number.

      sequence_nodes graph

      # Get the live ranges of all values.

      live_ranges = live_ranges(graph)

      # Run linear scan to allocate registers to values.

      registers = linear_scan(live_ranges)

      # Annotate the values with their registers.

      registers.each do |range, register|
        range.producer.props[:register] = register.name.to_s.downcase.to_sym
      end

      # Add move instructions to move values into the correct register
      # before a phi.

      add_phi_moves graph
    end

    # Give all nodes a linear sequence number. A node will always have a higher sequence
    # number than all of its inputs. This is similar to the partially order operation in
    # the scheduler, but we consider value inputs here as well as control inputs.

    def sequence_nodes(graph)
      # Note that this algorithm is very wasteful! It allocates two sides of a branch
      # the same sequence numbers. This means that to the linear scan values on both
      # sides of the branch and internal to those branches appear to be live at the
      # same time and they won't use the same registers. I think we're supposed to be
      # sequencing one side of the branch at a time, and starting the right side
      # with the max sequence number of the left side.

      # Create a worklist of nodes to sequence.

      to_sequence = graph.all_nodes

      until to_sequence.empty?
        node = to_sequence.shift

        # If all this node's inputs have already been sequenced.

        if node.inputs.from_nodes.all? { |i| i.props[:register_sequence] }
          # Give this node an sequence number at least one higher than all others.
          input_sequences = node.inputs.from_nodes.map { |i| i.props[:register_sequence] }
          node.props[:register_sequence] = if input_sequences.empty? then 0 else input_sequences.max + 1 end
          next
        end

        # Not all inputs were sequenced - put this node back on the list and try again later.

        to_sequence.push node
      end
    end

    # For each value produce an object which says when it is live from and until.

    def live_ranges(graph)
      graph.all_nodes.select { |n| n.produces_value? && n.op != :immediate }.map do |producer|
        # A value is live from when the node producing it runs...
        start = producer.props[:register_sequence]

        # Until the last node using it runs.
        finish = graph.all_nodes.select { |u| u.inputs.from_nodes.include?(producer) }.map { |u| u.props[:register_sequence] }.max

        LiveRange.new(producer, start, finish)
      end
    end

    LiveRange = Struct.new(:producer, :start, :finish)

    # Assign registers to live ranges using the linear scan algorithm.

    def linear_scan(live_ranges)
      # We've hardcoded the AMD64 architecture in here for now!

      # The registers currently available to store values in.
      available = Backend::AMD64::USER_REGISTERS.dup

      # The ranges which are currently active.
      active_ranges = []

      # Registers allocated to ranges.
      registers = {}

      # Separate argument live ranges from other ranges.
      argument_ranges, other_ranges = live_ranges.partition { |range| [:self, :arg].include?(range.producer.op) }

      # Artificially say that values for arguments start from
      # the start of the method, not from when the arg or self
      # node is scheduled, and allocate them the register they
      # will be in anyway.

      argument_ranges.each do |range|
        if range.producer.op == :self
          register = Backend::AMD64::ARGUMENT_REGISTERS[0]
        else
          register = Backend::AMD64::ARGUMENT_REGISTERS[range.producer.props[:n] + 1]
        end
        available.delete register
        registers[range] = register
        active_ranges.push range
      end

      # Then look at other ranges - go through each one in order of when
      # they start.

      other_ranges.sort_by(&:start).each do |range|
        # Retire any active ranges where we have no passed their finish point.

        active_ranges.dup.each do |a|
          if a.finish <= range.start
            active_ranges.delete a
            # Put their register back into the list of available registers.
            available.unshift registers[a]
          end
        end

        # If we have run out of registers we would spill and start to use the
        # stack to store values, but we haven't implemented this functionality.

        raise if available.empty?

        # Take a register and make this range as live.

        register = available.shift
        registers[range] = register
        active_ranges.push range
      end

      registers
    end

    # After we've allocated registers, however we've done it, we may not have
    # been able to get all inputs to a phi node to use the same register as
    # the phi node itself has (remembering that the input to a phi might be a
    # value that has other users, including other phis, so we can't just change
    # which register the input uses). In those cases, we may need to add moves
    # before the phi node to put them into the right place.

    def add_phi_moves(graph)
      to_remove = []

      phis = graph.find_nodes(:phi)

      phis.each do |phi|
        phi_register = phi.props[:register]
        merge = phi.inputs.with_input_name(:switch).nodes.first

        phi.inputs.edges.dup.each do |input|
          if input.value?
            input_register = input.from.props[:register]
            if input_register != phi_register
              # We want to add a move node, but by the time the register
              # allocator is run the graph is very complicated, with
              # data flow, control flow, and a local schedule. We'll ignore
              # most of that and just insert this move into the local
              # schedule.

              input.input_name =~ /value\((.*)\)/
              name = $1

              last_before_merge = merge.inputs.with_input_name(:"control(#{name})").nodes.first
              local_schedule_edge = last_before_merge.outputs.edges.find { |e| e.output_name == :local_schedule }

              move = IR::Node.new(:move, from: input_register, register: phi_register)
              local_schedule_edge.interdict move
              input.from.output_to input.output_name, move, :value
              move.output_to :value, input.to, input.input_name
              input.remove
            end
          end
        end

        to_remove.each(&:remove)
      end
    end

  end

end
