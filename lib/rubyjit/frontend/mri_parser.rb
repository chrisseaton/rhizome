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

    # A parser from the MRI bytecode format to the RubyJIT format.

    class MRIParser

      # Get the text of MRI bytecode for a method.

      def text_for(method)
        RubyVM::InstructionSequence.disasm(method).lines.drop(1).join
      end

      # Parse the text of MRI bytecode format to the RubyJIT format.

      def parse(text)
        lines = text.lines

        header = lines.shift.match(/local table \(size: (\d+), argc: (\d+) \[opts: (\d+), rest: (-?\d+), post: (\d+), block: (-?\d+), kw: (-?\d+)@(-?\d+), kwrest: (-?\d+)\]\)/)
        size, argc, opt, rest, post, block, kw1, kw2, kwrest = header.captures.map(&:to_i)

        raise 'optional arguments not supported' unless opt == 0
        raise 'rest arguments not supported' unless rest == -1
        raise 'post arguments not supported' unless post == 0
        raise 'blocks not supported' unless block == -1
        raise 'keyword arguments not supported' unless kw1 == -1 && kw2 == -1 && kwrest == -1

        locals = lines.shift.scan(/\[\s*\d+\] (\w+)<Arg>/).flatten.map(&:to_sym)

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
            when /(\d+)\s+trace\s+\d+\s+\(\s+(\d+)\)/
              insns.push [:trace, $2.to_i]
            when /(\d+)\s+putself/
              insns.push [:self]
            when /(\d+)\s+getlocal_OP__WC__0\s+(\d+)/
              insns.push [:load, locals[argc + size - $2.to_i]]
            when /(\d+)\s+putobject\s+(\d+)/
              insns.push [:push, $2.to_i]
            when /(\d+)\s+putobject_OP_INT2FIX_O_(\d+)_C_/
              insns.push [:push, $2.to_i]
            when /(\d+)\s+\w+\s+<callinfo\!mid:([+\-<>\w]+), argc:(\d+), (FCALL\|)?ARGS_SIMPLE>, <callcache>/
              insns.push [:send, $2.to_sym, $3.to_i]
            when /(\d+)\s+jump\s+(\d+)/
              insns.push [:branch, $2.to_i]
            when /(\d+)\s+branchunless\s+(\d+)/
              insns.push [:not]
              insns.push [:branchif, $2.to_i]
            when /(\d+)\s+leave/
              insns.push [:return]
            else
              raise 'unknown instruction'
          end

          # Remember that the MRI byte offset of this instruction was at this index in our array of instructions.

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
