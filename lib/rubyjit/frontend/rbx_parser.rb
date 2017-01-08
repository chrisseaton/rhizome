# Copyright (c) 2016-2017 Chris Seaton
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
  module Frontend

    # A parser from the Rubinius bytecode format to the RubyJIT format.

    class RbxParser

      # Get the text of Rubinius bytecode for a method.

      def text_for(method)
        executable = method.executable
        header = [executable.required_args, executable.post_args, executable.total_args,
                  executable.local_names.to_a]
        header.inspect + "\n" + executable.decode.map { |i| i.to_s.strip }.join("\n") + "\n"
      end

      # Parse the text of Rubinius bytecode format to the RubyJIT format.

      def parse(text)
        lines = text.lines

        header = eval(lines.shift)
        required, post, total, locals = header
        opt = total - required

        raise 'optional arguments not supported' unless opt == 0
        raise 'post arguments not supported' unless post == 0

        insns = []
        labels = {}

        # Explicitly load arguments into locals.

        locals.each_with_index do |name, n|
          insns.push [:arg, n]
          insns.push [:store, name]
        end

        # Translate each instruction.

        lines.each do |line|
          index = insns.size

          case line
            when /(\d+):\s+push_self/
              insns.push [:self]
            when /(\d+):\s+push_local\s+(\d+)\s+#.*/
              insns.push [:load, locals[$2.to_i]]
            when /(\d+):\s+push_int\s+(\d+)/
              insns.push [:push, $2.to_i]
            when /(\d+):\s+send_stack\s+:([\w\+\-<]+),\s+(\d+)/
              insns.push [:send, $2.to_sym, $3.to_i]
            when /(\d+):\s+goto\s+(\d+):/
              insns.push [:branch, $2.to_i]
            when /(\d+):\s+goto_if_false\s+(\d+):/
              insns.push [:not]
              insns.push [:branchif, $2.to_i]
            when /(\d+):\s+ret/
              insns.push [:return]
            when /(\d+):\s+allow_private/
            else
              raise 'unknown instruction'
          end

          # Remember that the Rubinius byte offset of this instruction was at this index in our array of instructions.

          labels[$1.to_i] = index
        end

        # Go back and modify branch targets - we didn't know offsets for forward jumps on the first pass.

        insns.each do |insn|
          if [:branch, :branchif].include?(insn.first)
            insn[1] = labels[insn[1]]
          end
        end

        insns
      end

    end

  end
end
