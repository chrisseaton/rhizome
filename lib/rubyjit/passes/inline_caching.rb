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
  module Passes

    # An optimisation pass to use information from a profile to do simple
    # monomorphic inline caching with a fast and slow path and guards
    # based on the kind of the receiver.

    class InlineCaching

      def run(graph)
        modified = false

        # Look at each send node, has profiling information, hasn't been
        # marked as megamorphic and doesn't have a receiver kind (so isn't
        # already the monomorphic part of an inline cache).

        graph.all_nodes.each do |n|
          if n.op == :send && n.props[:profile] && !n.props[:megamorphic] && !n.props[:kind]

            # The existing send node will become the megamorphic side
            # of the inline cache.

            original_send = n
            profile = original_send.props[:profile]

            # We can only apply this optimisation if there was only one kind
            # of receiver, because we only create monomorphic inline caches
            # here. If we handled more than one kind of receiver in a chain
            # then that would be a polymorphic inline cache, and more
            # complicated.

            if profile.receiver_kinds.size == 1
              kind = profile.receiver_kinds.first

              # We've only designed this to handle one control input and
              # output on the send. I'm not sure how it would work
              # in other cases.

              next if original_send.inputs.with_input_name(:control).size != 1
              next if original_send.outputs.with_output_name(:control).size != 1

              control_in = original_send.inputs.with_input_name(:control).edges.first.from
              control_out = original_send.outputs.with_output_name(:control).edges.first.to

              # Find the users of the node and their input names. We'll
              # reconnect them to another node later.

              user_edges = original_send.outputs.with_output_name(:value).edges
              user_nodes = user_edges.map { |e| [e.to, e.input_name] }

              # Disconnect control from the megamorphic send as well.

              original_send.inputs.with_input_name(:control).edges.first.remove
              original_send.outputs.with_output_name(:control).edges.first.remove

              # Create a new send that will our our monomorphic case. This
              # will call a specific method directly, not needing any method
              # lookup because we have already checked, or 'guarded' the
              # kind of the receiver.

              mega_send = IR::Node.new(:send, argc: original_send.props[:argc], name: original_send.props[:name], megamorphic: true, profile: profile)
              mono_send = IR::Node.new(:send, argc: original_send.props[:argc], name: original_send.props[:name], kind: kind, profile: profile)

              # Connect the same receiver and arguments to the new
              # sends as the current one had.

              original_send.inputs.with_input_name(:receiver).edges.first.from.output_to :value, mono_send, :receiver
              original_send.inputs.with_input_name(:receiver).edges.first.from.output_to :value, mega_send, :receiver

              original_send.props[:argc].times do |a|
                original_send.inputs.with_input_name(:"arg(#{a})").edges.first.from.output_to :value, mono_send, :"arg(#{a})"
                original_send.inputs.with_input_name(:"arg(#{a})").edges.first.from.output_to :value, mega_send, :"arg(#{a})"
              end

              # The guard node checks the kind of the receiver.

              guard = IR::Node.new(:kind_is?, kind: kind)
              original_send.inputs.with_input_name(:receiver).edges.first.from.output_to :value, guard

              # We then branch based on the value of the guard.

              branch = IR::Node.new(:branch)
              control_in.output_to :control, branch
              guard.output_to :value, branch, :condition

              # The branch goes to either the monomorphic case or the megamorphic case.

              branch.output_to :control, mono_send, :true
              branch.output_to :control, mega_send, :false

              # After running one of the calls we then merge the control flow
              # and the return value.

              merge = IR::Node.new(:merge)
              mono_send.output_to :control, merge, :'control(mono)'
              mega_send.output_to :control, merge, :'control(mega)'
              merge.output_to :control, control_out

              phi = IR::Node.new(:phi)
              merge.output_to :switch, phi
              mono_send.output_to :value, phi, :'value(mono)'
              mega_send.output_to :value, phi, :'value(mega)'

              user_nodes.each do |user, name|
                phi.output_to :value, user, name
              end

              # Remove the original send

              original_send.remove

              modified = true
            end
          end
        end

        modified
      end

    end

  end
end
