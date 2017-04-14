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
  module IR

    # The builder creates a graph from an array of instructions.

    class Builder

      attr_reader :graph

      def initialize
        @graph = Graph.new
      end

      # Build takes the array of instructions and adds them to the graph.

      def build(insns, profile=nil)
        # Find the basic blocks in the instructions.

        blocks = basic_blocks(insns)

        # Build each basic block into a graph fragment first.

        fragments = {}

        blocks.each do |ip, block|
          fragments[block.start] = basic_block_to_fragment(block.insns, ip, profile)
        end

        # Create more detailed, transitive, input and output names and stacks for each fragment.

        trans_names_in = {}
        trans_stack_in = {}

        trans_names_out = {}
        trans_stack_out = {}

        blocks.each_value do |block|
          fragment = fragments[block.start]

          block_trans_names_in = {}
          block_trans_stack_in = []

          # Combine the names and stack values that come in from previous blocks.

          if block.prev.size == 1
            # If the block has a single previous block, simply use all the names
            # and stack values out from that block.

            prev = block.prev.first

            block_trans_names_in.merge! trans_names_out[prev]
            block_trans_stack_in.push *trans_stack_out[prev]
          elsif block.prev.size > 1
            # If the block has multiple previous blocks then we could have
            # arrived at this basic block from either of them. That means that
            # values coming in for names or the stack. For each value that
            # comes in we join all the possible values in a phi node. The phi
            # node works as a switch to choose the correct value. It takes
            # input from the merge which starts this block, to tell it
            # which way to switch.

            # Find all the names out from all the previous blocks.

            all_names_out = block.prev.map { |p| trans_names_out[p].keys }.flatten.uniq.sort

            # See the number of stack values out from all the previous blocks.

            max_stack_out = block.prev.map { |p| trans_stack_out[p].size }.max

            # If all blocks don't have the same names and number of stack values we don't know what to do.

            block.prev.each do |prev|
              raise 'unsupported' unless trans_names_out[prev].keys.sort == all_names_out
              raise 'unsupported' unless trans_stack_out[prev].size == max_stack_out
            end

            # Create phis for each value

            all_names_out.each do |name|
              phi = Node.new(:phi)
              fragment.merge.output_to :switch, phi

              block.prev.each do |prev|
                trans_names_out[prev][name].output_to :value, phi, :"value(#{prev})"
              end

              block_trans_names_in[name] = phi
            end

            max_stack_out.times do |index|
              phi = Node.new(:phi)
              fragment.merge.output_to :switch, phi

              block.prev.each do |prev|
                trans_stack_out[prev][index].output_to :value, phi, :"value(#{prev})"
              end

              block_trans_stack_in.push phi
            end
          end

          # The output set is the same as the input set...

          block_trans_names_out = block_trans_names_in.dup
          block_trans_stack_out = block_trans_stack_in.dup

          # ...then add the new names and stack values from this fragment.

          fragment.names_out.each do |name, value|
            block_trans_names_out[name] = value
          end

          fragment.stack_out.each do |value|
            block_trans_stack_out.push value
          end

          # Remember this transitive set for this block.

          trans_names_in[block.start] = block_trans_names_in
          trans_stack_in[block.start] = block_trans_stack_in

          trans_names_out[block.start] = block_trans_names_out
          trans_stack_out[block.start] = block_trans_stack_out
        end

        # Connect the data flow between fragments, using the transitive sets.

        blocks.each_value do |block|
          fragment = fragments[block.start]

          fragment.names_in.each do |name, input|
            trans_names_in[block.start][name].output_to :value, input
          end

          fragment.stack_in.each_with_index do |input, index|
            trans_stack_in[block.start][index].output_to :value, input
          end
        end

        # Connect the control flow between fragments.

        blocks.each_value do |block|
          fragment = fragments[block.start]

          if block.prev.empty?
            # If the block has no previous blocks, connect the start of the
            # graph to it.

            @graph.start.output_to :control, fragment.merge
          end

          if block.next.empty?
            # If the block has no next blocks, connect it to the finish of
            # the graph.

            fragment.last_control.output_to :control, @graph.finish
            fragment.last_node.output_to :value, @graph.finish
          elsif block.next.size == 1
            # If the block has a single next block, connect the last control
            # node of this block to the merge node of the next block.

            next_i = block.next.first
            next_fragment = fragments[next_i]

            fragment.last_control.output_to :control, next_fragment.merge, :"control(#{block.start})"
          elsif fragment.last_control.op == :branch
            # If the block ends with a branch then it goes to two possible next
            # blocks. The branch node outputs two control edges, one labelled
            # true and one labelled false. This is the only place where control
            # forks like this.

            raise unless block.next.size == 2
            fragment.last_control.output_to :true, fragments[block.next[0]].merge, :control
            fragment.last_control.output_to :false, fragments[block.next[1]].merge, :control
          else
            raise 'unsupported'
          end
        end
      end

      # Finds the instructions that are the targets of jumping or branching,
      # or fallthrough from not branching.

      def targets(insns)
        targets = Set.new

        # The first instruction is implicitly jumped to when the function
        # starts.

        targets.add 0 unless insns.empty?

        # Look at each instruction. If it's a jump add its target to the list of
        # targets. If it's a branch then the branch may not be taken and so the
        # next instruction is also a target as well as the actual target.

        insns.each_with_index do |insn, index|
          if [:jump, :branch].include?(insn.first)
            targets.add insn[1]
            targets.add index + 1 if insn.first == :branch
          end
        end

        # Sort the targets so the output so we get the targets in the order
        # they appear.

        targets.to_a.sort
      end

      # A basic block is the address of the first instruction, the
      # instructions in it, and lists of previous and next basic blocks.

      BasicBlock = Struct.new(:start, :insns, :prev, :next)

      # Find the basic blocks in an array of instructions.

      def basic_blocks(insns)
        # Jump and branch targets give us the start of each basic block.

        targets = targets(insns)

        # Create a basic block for each jump or branch target.

        blocks = {}

        targets.each_with_index do |start, index|
          # Slice the instructions that form this block by looking for where
          # the next block starts.

          if index == targets.size - 1
            last = insns.size
          else
            last = targets[index + 1]
          end

          block_insns = insns.slice(start, last - start)

          last_insn = block_insns.last

          # Create an array for the previous basic blocks, but we'll fill it
          # in later.

          prev_blocks = []

          # Look at the last instruction and its targets to see what the next
          # possible basic blocks are.

          next_blocks = []
          next_blocks.push last_insn[1]        if [:jump, :branch].include?(last_insn.first)
          next_blocks.push targets[index + 1]  unless [:jump, :return].include?(last_insn.first)

          blocks[start] = BasicBlock.new(start, block_insns, prev_blocks, next_blocks)
        end

        # No go back and use the information about the basic blocks following
        # each block to store the reverse - the basic blocks previous to each
        # block.

        blocks.values.each do |block|
          block.next.each do |n|
            blocks[n].prev.push block.start
          end
        end

        blocks
      end

      # A graph fragment is some nodes that don't yet form a complete graph.
      # As well as the first node (always a merge node) and the last value
      # and last control node, we also store the unconnected parts of the
      # fragment - the names and stack values that come into this fragment,
      # and those that come out of this fragment.

      GraphFragment = Struct.new(:names_in, :stack_in, :merge, :last_node, :last_control, :names_out, :stack_out)

      # Convert one basic block to a fragment of graph.

      def basic_block_to_fragment(insns, ip=0, profile=nil)
        # Basic blocks start with a merge node.

        merge = Node.new(:merge)

        # We're going to build up a list of names and stack values coming into
        # this basic block that we're going to need to connect up later when
        # we form a complete graph.

        names_in = {}
        stack_in = []

        last_node = nil
        last_control = merge

        # We're also going to build up a list of names and stack values that
        # are available when this basic block is finished.

        names = {}
        stack = []

        # When we pop a value off the stack, we may be using a value that
        # wasn't created within this basic block - the value could have been
        # expected to be on the stack already. This proc tries to pop a value
        # off the basic block's stack, but if there isn't one, it then
        # records that the basic block will need another stack value coming in
        # and creates an unconnected value to represent that, called an input
        # node.

        pop = proc {
          if stack.empty?
            input = Node.new(:input)
            stack_in.unshift input
            input
          else
            stack.pop
          end
        }

        # Go through each instruction in the basic block, and perform a kind
        # of abstract interpretation on it. This loop looks a lot like the one
        # in the interpreter. The difference here is that we don't deal with
        # real values, instead we deal with an abstraction of the values that
        # will be there in the future. It's somewhat like computing with
        # promises that are never fulfilled. It's simpler than it sounds
        # because as this is a basic block the control flow is simple - it's a
        # linear sequence of instructions with no branches. For each
        # instruction we create a graph node that represents the computation
        # on the abstract values. We build a backbone of linear control flow
        # through the instructions by linking each instruction that has some
        # kind of side effect to the previous instruction with a side effect.

        insns.each_with_index do |insn, n|
          case insn.first
            when :trace
              last_node = Node.new(:trace, line: insn[1])
            when :self
              last_node = Node.new(:self)
              stack.push last_node
            when :arg
              last_node = Node.new(:arg, n: insn[1])
              stack.push last_node
            when :load
              name = insn[1]
              value = names[name]
              unless value

                # Like the pop proc, if we don't find that a name has been set
                # in this basic block, we remember that we need it as an input
                # and create an input node to represent its future value.

                input = Node.new(:input)
                names_in[name] = input
                names[name] = input
                value = input
              end
              stack.push value
            when :store
              names[insn[1]] = pop.call
            when :push
              last_node = Node.new(:constant, value: insn[1])
              stack.push last_node
            when :send
              name = insn[1]
              argc = insn[2]
              send_node = Node.new(:send, name: name, argc: argc)
              argc.times do |n|
                arg_node = pop.call
                arg_node.output_to :value, send_node, :"arg(#{argc-n-1})"
              end
              receiver_node = pop.call
              receiver_node.output_to :value, send_node, :receiver
              if profile
                send_node.props[:profile] = profile.sends[ip + n]
              end
              stack.push send_node
              last_node = send_node
            when :not
              value_node = pop.call
              not_node = Node.new(:not)
              value_node.output_to :value, not_node
              stack.push not_node
              last_node = not_node
            when :jump
              jump_node = Node.new(:jump)
              last_node = jump_node
            when :branch
              value_node = pop.call
              branch_node = Node.new(:branch)
              value_node.output_to :value, branch_node, :condition
              last_node = branch_node
            when :return
              last_node = pop.call
              stack.push last_node
            else
              raise 'unknown instruction'
          end

          # The trace and send instructions have side effects - link them into
          # the backbone of control flow so that we know one instruction with
          # side effects needs to happen before any other after it. The jump and
          # branch instructions could or could not be seen as side effects. We
          # treat them so because it seems to make this easier.

          if [:trace, :send, :jump, :branch].include?(insn.first)
            last_control.output_to :control, last_node
            last_control = last_node
          end
        end

        GraphFragment.new(names_in, stack_in, merge, last_node, last_control, names, stack)
      end

    end

  end
end
