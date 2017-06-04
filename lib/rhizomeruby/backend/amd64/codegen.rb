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

module Rhizome
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
          # Saved all callee-saved registers - should really just be those that we use.

          CALLEE_SAVED.each do |r|
            @assembler.push r
          end

          # The size of the farme is the callee-saved registers plus one for our return address.

          frame_size = CALLEE_SAVED.size + 1

          # Store the start of our actual frame in RBP

          @assembler.mov RSP, RBP

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
                  source = source_for_arg(:self)
                  @assembler.mov source, operand(dest) if source != operand(dest)
                when :arg
                  _, n, dest = insn
                  source = source_for_arg(n)
                  @assembler.mov source, operand(dest) if source != operand(dest)
                when :constant
                  _, value, dest = insn
                  # TODO we should differentiate clearly between untagged constant numbers and object constants
                  value = @handles.to_native(value) unless value.is_a?(Integer)
                  @assembler.mov Value.new(value), prepare_output(dest)
                  finish_output dest
                when :move
                  _, source, dest = insn
                  source = prepare_input(source)
                  @assembler.mov source, prepare_output(dest)
                  finish_output dest
                when :int64_add
                  _, a, b, dest = insn
                  a, b = associative_swap_for_dest(a, b, dest)
                  a = prepare_input(a)
                  prepare_input_output b, dest
                  @assembler.add a, prepare_output(dest)
                  finish_output dest
                when :int64_imul
                  _, a, b, dest = insn
                  a, b = associative_swap_for_dest(a, b, dest)
                  a = prepare_input(a)
                  prepare_input_output b, dest
                  @assembler.imul a, prepare_output(dest)
                  finish_output dest
                when :int64_and
                  _, a, b, dest = insn
                  a, b = associative_swap_for_dest(a, b, dest)
                  a = prepare_input(a)
                  prepare_input_output b, dest
                  @assembler.and a, prepare_output(dest)
                  finish_output dest
                when :int64_shift_left, :int64_shift_right
                  _, a, b, dest = insn
                  a = prepare_input_output(a, dest)
                  if b.is_a?(Integer)
                    if insn.first == :int64_shift_left
                      @assembler.shl Value.new(b), a
                    else
                      @assembler.shr Value.new(b), a
                    end
                  else
                    raise unless SCRATCH_REGISTERS.include?(RCX)
                    @assembler.mov operand(b), RCX if operand(b) != RCX
                    if insn.first == :int64_shift_left
                      @assembler.shl RCX, a
                    else
                      @assembler.shr RCX, a
                    end
                  end
                  finish_output dest
                when :jump
                  _, target = insn
                  @assembler.jmp labels[target]
                when :branch_if
                  _, value, target, cond = insn
                  value = prepare_input(value)
                  case cond
                    when :int64_zero?
                      @assembler.mov Value.new(0), SCRATCH_REGISTERS[1]
                      @assembler.cmp value, SCRATCH_REGISTERS[1]
                      @assembler.je labels[target]
                    when :int64_not_zero?
                      @assembler.mov Value.new(0), SCRATCH_REGISTERS[1]
                      @assembler.cmp value, SCRATCH_REGISTERS[1]
                      @assembler.jne labels[target]
                    else
                      raise
                  end
                when :branch_unless
                  _, value, target, cond = insn
                  value = prepare_input(value)
                  case cond
                    when :int64_not_zero?
                      @assembler.mov Value.new(0), SCRATCH_REGISTERS[1]
                      @assembler.cmp value, SCRATCH_REGISTERS[1]
                      @assembler.je labels[target]
                    else
                      raise
                  end
                when :guard
                  _, value, cond = insn
                  value = prepare_input(value)
                  case cond
                    when :int64_zero?
                      @assembler.mov Value.new(0), SCRATCH_REGISTERS[1]
                      @assembler.cmp value, SCRATCH_REGISTERS[1]
                      deopts.push DeoptPoint.new(@assembler.jne, frame_state)
                    when :int64_not_zero?
                      @assembler.mov Value.new(0), SCRATCH_REGISTERS[1]
                      @assembler.cmp value, SCRATCH_REGISTERS[1]
                      deopts.push DeoptPoint.new(@assembler.je, frame_state)
                    else
                      raise
                  end
                when :call_managed
                  _, receiver, name, *args, target = insn

                  # Save all caller-saved registers - should really just be those that
                  # actually have live values in them.

                  CALLER_SAVED.each do |r|
                    @assembler.push r
                  end

                  # The frame size will the original frame size, plus the caller-saved,
                  # plus the arguments. Push another value to align it to 16-byte if
                  # needed.

                  new_frame_size = frame_size + CALLER_SAVED.size + args.size

                  if new_frame_size % 2 == 1
                    @assembler.push SCRATCH_REGISTERS[0]
                  end

                  # Push arguments.

                  args.reverse.each do |arg|
                    @assembler.push operand(arg)
                  end

                  # Push the method name and the receiver.

                  @assembler.mov operand(name), SCRATCH_REGISTERS[0]
                  @assembler.push SCRATCH_REGISTERS[0]
                  @assembler.mov operand(receiver), SCRATCH_REGISTERS[0]
                  @assembler.push SCRATCH_REGISTERS[0]

                  # The first argument is then the current stack pointer, and the second is the number of arguments.

                  @assembler.mov RSP, RDI
                  @assembler.mov Value.new(args.size), RSI

                  # Call into managed.

                  @assembler.call Value.new(@interface.call_managed_address)

                  # Pop args back off.

                  (args.size + 2).times do
                    raise if SCRATCH_REGISTERS[1] == RAX
                    @assembler.pop SCRATCH_REGISTERS[1]
                  end

                  # Restore registers that we preserved

                  if new_frame_size % 2 == 1
                    raise if SCRATCH_REGISTERS[1] == RAX
                    @assembler.pop SCRATCH_REGISTERS[1]
                  end

                  CALLER_SAVED.reverse.each do |r|
                    raise if r == RAX
                    @assembler.pop r
                  end

                  @assembler.mov RAX, operand(target)
                when :return
                  _, source = insn

                  @assembler.mov operand(source), RAX

                  # Restore the caller's stack pointer.

                  @assembler.mov RBP, RSP

                  # Don't trash the return value!

                  raise if CALLEE_SAVED.include?(RAX)

                  # Restore caller-saved registers.

                  CALLEE_SAVED.reverse.each do |r|
                    @assembler.pop r
                  end

                  @assembler.ret
                when :frame_state
                  _, insns, ip, receiver, args = insn
                  frame_state = FrameStateGen.new(insns, ip, receiver, args)
                when :nop
                  # Emit nothing - doesn't also need a machine nop instruction.
                else
                  raise
              end
            end
          end
          
          # Now emit all deoptimisation routines.
          
          deopts.each do |deopt|
            @assembler.label deopt.label

            # Push all user registers - should really just be those with live values in them.

            USER_REGISTERS.each do |r|
              @assembler.push r
            end

            # The frame size now includes those registers - push another value to align to
            # 16-bytes if needs be.

            new_frame_size = frame_size + USER_REGISTERS.size

            if new_frame_size % 2 == 1
              @assembler.push SCRATCH_REGISTERS[0]
            end

            # Call the continue-in-interpreter routine, giving it the address of the
            # stack so it can read it, and the frame state so it can understand the
            # values on the stack.

            @assembler.mov RBP, RDI
            @assembler.mov RSP, RSI
            @assembler.mov Handle.new(deopt.frame_state), RDX
            @assembler.call Value.new(@interface.continue_in_interpreter_address)

            # Don't trash the return value!

            raise if SCRATCH_REGISTERS[1] == RAX
            raise if USER_REGISTERS.include?(RAX)

            # Restore the caller's stack pointer. This will pop off the registers
            # and possible alignment value that we pushed.

            @assembler.mov RBP, RSP

            # Restore caller-saved registers.

            CALLEE_SAVED.reverse.each do |r|
              @assembler.pop r
            end

            @assembler.ret
          end
        end

        private

        def associative_swap_for_dest(a, b, dest)
          b, a = a, b if a == dest
          [a, b]
        end

        def prepare_input(source)
          if register?(source)
            operand(source)
          else
            raise
          end
        end

        def prepare_input_output(source, dest)
          if register?(dest)
            if source != dest
              @assembler.mov operand(source), operand(dest)
            end
            operand(dest)
          else
            # If we supported stack values, we'd need to move the source
            # into the dest register here.
          end
        end

        def prepare_output(dest)
          if register?(dest)
            operand(dest)
          else
            # If we supported stack values, we'd need to move the source
            # off the stack into a scratch register here.
          end
        end

        def finish_output(dest)
          # If we supported stack values, we'd need to move the scratch
          # register into the stack here.
        end

        def register?(storage)
          storage.to_s.start_with?('r')
        end

        def operand(storage)
          if register?(storage)
            AMD64.const_get(storage.to_s.upcase.to_sym)
          else
            # If we supported stack values we'd do with arithmetic with
            # RBP here.
          end
        end

        def source_for_arg(n)
          if n == :self
            RDI
          else
            [RSI, RDX].fetch(n)
          end
        end

      end

    end
  end
end
