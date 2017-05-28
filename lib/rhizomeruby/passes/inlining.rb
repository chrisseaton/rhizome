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
  module Passes

    # A pass that inlines send nodes with the body of the called method.

    class Inlining

      def initialize
        @core = IR::Core.new
      end

      def run(graph)
        modified = false

        # Look at each send node which has a profile, isn't megamorphic, and
        # has a receiver kind.

        graph.all_nodes.each do |n|
          if n.op == :send && n.props[:profile] && !n.props[:megamorphic] && n.props[:kind]
            send = n

            # Look at the kind and the name.

            case [send.props[:kind], send.props[:name]]

              # Core library methods.

              when [:fixnum, :+]
                inlined = @core.fixnum_op(:+, send.props[:profile])
              when [:fixnum, :-]
                inlined = @core.fixnum_op(:-, send.props[:profile])
              when [:fixnum, :*]
                inlined = @core.fixnum_op(:*, send.props[:profile])

              # Otherwise this isn't a send that we can inline.

              else
                next
            end

            # Find all the self and arg nodes in the method body we're going
            # to inline. We do this before we start modifying the graph as
            # when we start to make changes we'll get an inconsistent view
            # of the graph.

            selves = inlined.find_nodes(:self)
            args = inlined.find_nodes(:arg)

            # Replace each self node in the method body being inlined with a
            # connection node that goes to the input that was the receiver
            # for this send...

            selves.each do |s|
              receiver = send.inputs.with_input_name(:receiver).edges.first.from
              receiver.output_to :value, s
              s.replace IR::Node.new(:connector)
            end

            # ...and do the same thing for each argument.

            args.each do |a|
              arg = send.inputs.with_input_name(:"arg(#{a.props[:n]})").edges.first.from
              arg.output_to :value, a
              a.replace IR::Node.new(:connector)
            end

            # Replace the send node with the inlined method body.

            send.replace inlined.start, inlined.finish, [], inlined.finish

            # Replace the inlined method's start and finish nodes with
            # connectors instead.

            inlined.start.replace IR::Node.new(:connector)
            inlined.finish.replace IR::Node.new(:connector)

            modified = true
          end
        end

        modified
      end

    end

  end
end
