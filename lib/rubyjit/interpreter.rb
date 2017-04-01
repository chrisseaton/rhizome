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
  
  # An interpreter for RubyJIT bytecode.
  
  class Interpreter
    
    def interpret(insns, receiver, args, profiler=nil, ip=0, stack=[], locals={})
      # Loop through instructions.
      
      loop do
        insn = insns[ip]
        
        # Look at the instruction name and execute its action.

        case insn.first
          when :trace
            ip += 1
          when :self
            stack.push receiver
            ip += 1
          when :arg
            stack.push args[insn[1]]
            ip += 1
          when :load
            stack.push locals[insn[1]]
            ip += 1
          when :store
            locals[insn[1]] = stack.pop
            ip += 1
          when :push
            stack.push insn[1]
            ip += 1
          when :send
            send_name = insn[1]
            send_argc = insn[2]
            send_args = []
            send_argc.times do
              send_args.push stack.pop
            end
            send_receiver = stack.pop
            profiler.profile_send(ip, send_receiver, send_args) if profiler
            stack.push send_receiver.send(send_name, *send_args)
            ip += 1
          when :not
            stack.push !stack.pop
            ip += 1
          when :jump
            ip = insn[1]
          when :branch
            if stack.pop
              ip = insn[1]
            else
              ip += 1
            end
          when :return
            return stack.pop
          else
            raise 'unknown instruction'
        end
      end
    end
    
  end
  
end
