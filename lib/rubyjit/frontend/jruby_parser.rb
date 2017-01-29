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

    # A parser from the JRuby bytecode format to the RubyJIT format.

    class JRubyParser

      # Get the text of JRuby bytecode for a method.

      def text_for(method)
        method.to_java.get_method.ensure_instrs_ready.get_instructions.map(&:to_s).join("\n") + "\n"
      end

      # Parse the text of JRuby bytecode format to the RubyJIT format.

      def parse(text)
        lines = text.lines

        insns = []
        labels = {}

        # Translate each instruction.
        
        arg_n = 0

        lines.each do |line|
          index = insns.size

          case line
            when /\[DEAD\].*/
            when /%[\w_]+ = load_implicit_closure\(\)/
            when /%[\w_]+ = copy\(scope<\d+>\)/
            when /%[\w_]+ = copy\(module<\d+>\)/
            when /check_arity\(;req: (\d+), opt: (\d+), \*r: false, kw: false\)/
              opt = $2.to_i
              raise 'optional arguments not supported' unless opt == 0
            when /line_num\(;n: (\d+)\)/
              insns.push [:trace, $1.to_i]
            when /(\w+)\(\d+:\d+\) = recv_pre_reqd_arg\(\)/
              insns.push [:arg, arg_n]
              insns.push [:store, $1.to_sym]
              arg_n += 1
            when /label\((LBL_\d+:\d+)\)/
              labels[$1.to_sym] = index
            when /%([\w_]+) = copy\(([\w_]+)\(\d+:\d+\)\)/
              insns.push [:load, $2.to_sym]
              insns.push [:store, $1.to_sym]
            when /%([\w_]+) = copy\(%([\w_]+)\)/
              insns.push [:load, $2.to_sym]
              insns.push [:store, $1.to_sym]
            when /%([\w_]+) = call_1[of]\((\w+)\(\d+:\d+\), (\w+)\(\d+:\d+\) ;n:([\w\+<-]+), t:(NO|FU), cl:false\)/
              insns.push [:load, $2.to_sym]
              insns.push [:load, $3.to_sym]
              insns.push [:send, $4.to_sym, 1]
              insns.push [:store, $1.to_sym]
            when /%([\w_]+) = call_1[of]\(n\(\d+:\d+\), Fixnum:(\d+) ;n:([\w\+<-]+), t:(NO|FU), cl:false\)/
              insns.push [:load, :n]
              insns.push [:push, $2.to_i]
              insns.push [:send, $3.to_sym, 1]
              insns.push [:store, $1.to_sym]
            when /%([\w_]+) = call_1[of]\(%self, %([\w_]+) ;n:([\w\+<-]+), t:(NO|FU), cl:false\)/
              insns.push [:self]
              insns.push [:load, $2.to_sym]
              insns.push [:send, :fib, 1]
              insns.push [:store, $1.to_sym]
            when /%([\w_]+) = call_1[of]\(%([\w_]+), %([\w_]+) ;n:([\w\+<-]+), t:(NO|FU), cl:false\)/
              insns.push [:load, $2.to_sym]
              insns.push [:load, $3.to_sym]
              insns.push [:send, $4.to_sym, 1]
              insns.push [:store, $1.to_sym]
            when /jump\((LBL_\d+:\d+)\)/
              insns.push [:jump, $1.to_sym]
            when /b_false\((LBL_\d+:\d+), %([\w_]+)\)/
              insns.push [:load, $2.to_sym]
              insns.push [:not]
              insns.push [:branch, $1.to_sym]
            when /return\(%([\w_]+)\)/
              insns.push [:load, $1.to_sym]
              insns.push [:return]
            else
              raise 'unknown instruction'
          end
        end

        # Go back and modify jump and branch targets - we didn't know offsets for forward jumps on the first pass.

        insns.each do |insn|
          if [:jump, :branch].include?(insn.first)
            insn[1] = labels[insn[1]]
          end
        end

        insns
      end

    end

  end
end
