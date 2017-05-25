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
  module IR

    # Methods from the Ruby core library, written as Rhizome IR so that
    # they can be inlined.

    class Core

      # An operation on a fixnum.
      
      def fixnum_op(op, profile)
        # Fixnum operations branch between a primitive operation that
        # can be used when the operand is also a fixnum, and a megamorphic
        # call which handles anything else.

        graph = Graph.new

        receiver = Node.new(:self)
        arg = Node.new(:arg, n: 0)
        
        op_node = Node.new(:"fixnum_#{{:+ => 'add', :- => 'sub'}[op]}", argc: 1)
        receiver.output_to :value, op_node, :receiver
        arg.output_to :value, op_node, :'arg(0)'

        mega_send = Node.new(:send, name: op, argc: 1, profile: profile, megamorphic: true, uncommon: true)
        receiver.output_to :value, mega_send, :receiver
        arg.output_to :value, mega_send, :'arg(0)'

        guard = IR::Node.new(:kind_is?, kind: :fixnum)
        arg.output_to :value, guard
        
        branch = IR::Node.new(:branch)
        graph.start.output_to :control, branch
        guard.output_to :value, branch, :condition

        branch.output_to :true, op_node, :control
        branch.output_to :false, mega_send, :control

        merge = IR::Node.new(:merge)
        op_node.output_to :control, merge, :'control(fixnum)'
        mega_send.output_to :control, merge, :'control(mega)'
        merge.output_to :control, graph.finish

        phi = IR::Node.new(:phi)
        merge.output_to :switch, phi
        op_node.output_to :value, phi, :'value(fixnum)'
        mega_send.output_to :value, phi, :'value(mega)'
        phi.output_to :value, graph.finish

        graph
      end
      
    end
  end
end
