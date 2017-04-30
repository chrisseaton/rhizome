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

module RubyJIT

  # The register allocator annotates nodes in a graph which produce a value
  # with either the name of a register or a memory location in which the
  # value will be stored.

  class RegisterAllocator

    # The infinite allocator is a tool for demonstrations and writing tests
    # which puts each value into a unique register, without worrying about how
    # many registers this will need or whether we could reuse registers already
    # used for a value that is no longer needed.

    def allocate_infinite(graph)
      # Assign each node a unique register

      n = 0
      graph.all_nodes.each do |node|
        if node.produces_value?
          node.props[:register] = :"r#{n}"
          n += 1
        end
      end

      # We're going to need to move all inputs to a phi into the phi node's
      # register

      add_phi_moves graph
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
