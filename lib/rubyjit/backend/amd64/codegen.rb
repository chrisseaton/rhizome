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
  module Backend
    module AMD64

      # Code generation for AMD64.

      DeoptPoint = Struct.new(:label, :frame_state)
      FrameStateGen = Struct.new(:insns, :ip, :receiver, :args)

      class Codegen

        def initialize(assembler, handles, interface)
          @assembler = assembler
          @handles = handles
          @interface = interface
        end

        # Generate code for a set of linearised basic blocks.

        def generate(blocks)
          # Look for the highest stack slot used to see how much stack space we need to reserve.

          max_slot = 0

          blocks.each do |block|
            block.each do |insn|
              insn.each do |element|
                if element.is_a?(Symbol) && element.to_s.start_with?('s')
                  slot = element.to_s[1..-1].to_i
                  max_slot = [slot, max_slot].max
                end
              end
            end
          end

          stack_space = max_slot + 8
          
          #stack_space += stack_space % 16

          # Standard AMD64 function prelude - preserve the caller's rbp and create our stack space.

          @assembler.push RBP
          @assembler.mov RSP, RBP

          @assembler.mov Value.new(stack_space), RAX
          @assembler.sub RAX, RSP

          # Create labels for all basic blocks.

          labels = {}

          blocks.size.times do |n|
            labels[:"block#{n}"] = General::Label.new(@assembler)
          end
          
          # Build up an array of deoptimisation points to emit at the end of
          # the method, when all the fast-path code is out of the way, and
          # keep track of the current frame state.
          
          deopts = []
          frame_state = nil

          # Emit code for each basic block.

          blocks.each_with_index do |block, n|
            # Mark the basic block's label here.

            labels[:"block#{n}"].mark

            # Emit code for each instruction.

            block.each do |insn|
              case insn.first
                when :self
                  _, dest = insn
                  @assembler.mov RDI, operand(dest)
                when :arg
                  _, n, dest = insn
                  case n
                    when 0
                      source = RSI
                    when 1
                      source = RDX
                    else
                      raise n.to_s
                  end
                  @assembler.mov source, operand(dest)
                when :constant
                  _, value, dest = insn
                  # TODO we should differentiate clearly between untagged constant numbers and object constants
                  value = @handles.to_native(value) unless value.is_a?(Integer)
                  @assembler.mov Value.new(value), RAX
                  @assembler.mov RAX, operand(dest)
                when :move
                  _, source, dest = insn
                  @assembler.mov operand(source), RAX
                  @assembler.mov RAX, operand(dest)
                when :int64_add
                  _, a, b, dest = insn
                  @assembler.mov operand(a), RAX
                  @assembler.mov operand(b), RCX
                  @assembler.add RCX, RAX
                  @assembler.mov RAX, operand(dest)
                when :int64_and
                  _, a, b, dest = insn
                  @assembler.mov operand(a), RAX
                  @assembler.mov operand(b), RCX
                  @assembler.and RCX, RAX
                  @assembler.mov RAX, operand(dest)
                when :int64_shift_right
                  _, a, b, dest = insn
                  @assembler.mov operand(a), RAX
                  @assembler.mov operand(b), RCX
                  @assembler.shr RCX, RAX
                  @assembler.mov RAX, operand(dest)
                when :int64_shift_left
                  _, a, b, dest = insn
                  @assembler.mov operand(a), RAX
                  @assembler.mov operand(b), RCX
                  @assembler.shl RCX, RAX
                  @assembler.mov RAX, operand(dest)
                when :jump
                  _, target = insn
                  @assembler.jmp labels[target]
                when :branch_if
                  _, value, target, cond = insn
                  @assembler.mov operand(value), RAX
                  case cond
                    when :int64_zero?
                      @assembler.mov Value.new(0), RCX
                      @assembler.cmp RAX, RCX
                      @assembler.je labels[target]
                    when :int64_not_zero?
                      @assembler.mov Value.new(0), RCX
                      @assembler.cmp RAX, RCX
                      @assembler.jne labels[target]
                    else
                      raise
                  end
                when :branch_unless
                  _, value, target, cond = insn
                  @assembler.mov operand(value), RAX
                  case cond
                    when :int64_not_zero?
                      @assembler.mov Value.new(0), RCX
                      @assembler.cmp RAX, RCX
                      @assembler.je labels[target]
                    else
                      raise
                  end
                when :guard
                  _, value, cond = insn
                  @assembler.mov operand(value), RAX
                  case cond
                    when :int64_zero?
                      @assembler.mov Value.new(0), RCX
                      @assembler.cmp RAX, RCX
                      deopts.push DeoptPoint.new(@assembler.jne, frame_state)
                    when :int64_not_zero?
                      @assembler.mov Value.new(0), RCX
                      @assembler.cmp RAX, RCX
                      deopts.push DeoptPoint.new(@assembler.je, frame_state)
                    else
                      raise
                  end
                when :call_managed
                  _, receiver, name, *args, target = insn
                  args.reverse.each do |arg|
                    @assembler.mov operand(arg), RAX
                    @assembler.push RAX
                  end
                  @assembler.mov operand(name), RAX
                  @assembler.push RAX
                  @assembler.mov operand(receiver), RAX
                  @assembler.push RAX
                  @assembler.mov RSP, RDI
                  @assembler.mov Value.new(args.size), RSI
                  @assembler.mov Value.new(@interface.call_managed_address), RAX
                  @assembler.call Indirection.new(RAX)
                  @assembler.mov RAX, operand(target)
                  (args.size + 2).times do
                    @assembler.pop RAX
                  end
                when :return
                  _, source = insn
                  @assembler.mov operand(source), RAX
                  @assembler.mov RBP, RSP
                  @assembler.pop RBP
                  @assembler.ret
                when :frame_state
                  _, insns, ip, receiver, args = insn
                  frame_state = FrameStateGen.new(insns, ip, receiver, args)
                else
                  raise
              end
            end
          end
          
          # Now emit all deoptimisation routines.
          
          deopts.each do |deopt|
            @assembler.label deopt.label
            @assembler.mov RBP, RDI
            @assembler.mov RSP, RSI
            @assembler.mov Value.new(@handles.to_native(deopt.frame_state)), RDX
            @assembler.mov Value.new(@interface.continue_in_interpreter_address), RAX
            @assembler.call Indirection.new(RAX)
            @assembler.mov RBP, RSP
            @assembler.pop RBP
            @assembler.ret
          end
        end

        private

        def operand(bar)
          if bar.to_s.start_with?('r')
            raise
          elsif bar.to_s.start_with?('s')
            RBP - bar.to_s[1..-1].to_i
          else
            raise
          end
        end

      end

    end
  end
end
