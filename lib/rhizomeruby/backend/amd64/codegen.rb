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

      DeoptPoint = Struct.new(:label, :deopt_map)
      DeoptMapGen = Struct.new(:insns, :ip, :receiver, :args, :stack)

      class Codegen

        def initialize(assembler, handles, interface)
          @assembler = assembler
          @handles = handles
          @interface = interface
        end

        # Generate code for a set of linearised basic blocks.

        def generate(blocks)
          # Find all the registers we're going to use.

          used_registers = Set.new(blocks.flat_map { |block|
            block.flat_map { |insn|
              insn.drop(1).select { |operand| register?(operand) }
            }
          })

          used_registers.merge SCRATCH_REGISTERS

          # Saved all callee-saved registers that we use.

          called_saved_used = used_registers.intersection(CALLEE_SAVED).to_a
          called_saved_used.delete RBP
          called_saved_used.unshift RBP

          called_saved_used.each do |r|
            @assembler.push r
          end

          # The size of the frame is the callee-saved registers plus one for our return address.

          frame_size = called_saved_used.size + 1

          # Store the start of our actual frame in RBP

          @assembler.mov RSP, RBP

          # Create labels for all basic blocks.

          labels = {}

          blocks.size.times do |n|
            labels[:"block#{n}"] = General::Label.new(@assembler)
          end
          
          # Build up a map of deoptimisation points to emit at the end of
          # the method, when all the fast-path code is out of the way, and
          # keep track of the current deoptimisation map. It's a map so we can
          # look up if we've already created a deoptimisation point for
          # a given deoptimisation map - we don't want to create multiple
          # deoptimisation points that all actually do the same thing.

          deopts = {}
          deopt_map = nil

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
                      @assembler.cmp Value.new(0), value
                      @assembler.je labels[target]
                    when :int64_not_zero?
                      @assembler.cmp Value.new(0), value
                      @assembler.jne labels[target]
                    else
                      raise
                  end
                when :branch_unless
                  _, value, target, cond = insn
                  value = prepare_input(value)
                  case cond
                    when :int64_not_zero?
                      @assembler.cmp Value.new(0), value
                      @assembler.je labels[target]
                    else
                      raise
                  end
                when :guard
                  _, value, cond = insn
                  value = prepare_input(value)
                  case cond
                    when :int64_zero?
                      @assembler.cmp Value.new(0), value
                      instruction = :jne
                    when :int64_not_zero?
                      @assembler.cmp Value.new(0), value
                      instruction = :je
                    else
                      raise
                  end
                  deopt_point = deopts[deopt_map]
                  if deopt_point
                    @assembler.send instruction, deopt_point.label
                  else
                    deopts[deopt_map] = DeoptPoint.new(@assembler.send(instruction), deopt_map)
                  end
                when :call_managed
                  _, receiver, name, *args, target, live_registers = insn

                  # If we have live values in registers that AMD64 says are callee-saved
                  # then we need to preserve them by pushing them onto the stack.

                  live_registers ||= CALLER_SAVED

                  live_registers.each do |r|
                    @assembler.push r
                  end

                  # The frame size will the original frame size, plus the caller-saved,
                  # plus the arguments. Push another value to align it to 16-byte if
                  # needed.

                  new_frame_size = frame_size + live_registers.size + args.size

                  if new_frame_size % 2 == 1
                    @assembler.push SCRATCH_REGISTERS[0]
                  end

                  # Push arguments.

                  args.reverse.each do |arg|
                    @assembler.push operand(arg)
                  end

                  # Push the method name and the receiver.

                  raise unless register?(name)
                  @assembler.push operand(name)
                  raise unless register?(receiver)
                  @assembler.push operand(receiver)

                  # The first argument is then the current stack pointer, and the second is the number of arguments.

                  @assembler.mov RSP, RDI
                  @assembler.mov Value.new(args.size), RSI

                  # Call into managed.

                  @assembler.call Value.new(@interface.call_managed_address)

                  # Pop the arguments and padding back off.

                  to_pop = args.size + 2

                  if new_frame_size % 2 == 1
                    to_pop += 1
                  end

                  @assembler.add Value.new(to_pop * 8), RSP

                  # Restore registers that we saved.

                  live_registers.reverse.each do |r|
                    raise if r == RAX # Don't trash the return value!
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

                  called_saved_used.reverse.each do |r|
                    @assembler.pop r
                  end

                  @assembler.ret
                when :deopt_map
                  _, insns, ip, receiver, args, stack = insn
                  deopt_map = DeoptMapGen.new(insns, ip, receiver, args, stack)
                when :nop
                  # Emit nothing - doesn't also need a machine nop instruction.
                else
                  raise
              end
            end
          end
          
          # Now emit all deoptimisation routines.
          
          deopts.each_value do |deopt|
            @assembler.label deopt.label

            # If we don't have a deoptimisation map (we turn them off for some examples) just
            # emit a breakpoint instead of a deoptimisation routine.

            unless deopt.deopt_map
              @assembler.int 3
              next
            end

            # Push registers that have live values in them so that the deoptimisation
            # routine can read them off the stack.

            @assembler.mov Value.new(1234), RAX
            @assembler.push RAX

            @assembler.push operand(deopt.deopt_map.receiver)

            deopt.deopt_map.args.each do |r|
              @assembler.push operand(r)
            end

            deopt.deopt_map.stack.each do |r|
              @assembler.push operand(r)
            end

            # The frame size now includes those registers - push another value to align to
            # 16-bytes if needs be.

            new_frame_size = frame_size + deopt.deopt_map.args.size + deopt.deopt_map.stack.size

            if new_frame_size % 2 == 1
              @assembler.push SCRATCH_REGISTERS[0]
            end

            # Call the continue-in-interpreter routine, giving it the address of the
            # stack so it can read it, and the deoptimisation map so it can understand the
            # values on the stack.

            @assembler.mov RBP, RDI
            @assembler.mov RSP, RSI
            @assembler.mov Handle.new(deopt.deopt_map), RDX
            @assembler.call Value.new(@interface.continue_in_interpreter_address)

            # Don't trash the return value!

            raise if SCRATCH_REGISTERS[1] == RAX

            # Restore the caller's stack pointer. This will pop off the registers that
            # we pushed for live values.

            @assembler.mov RBP, RSP

            # Restore caller-saved registers.

            called_saved_used.reverse.each do |r|
              @assembler.pop r
            end

            @assembler.ret
          end
        end

        private

        def associative_swap_for_dest(a, b, dest)
          if b.is_a?(Integer) || a == dest
            b, a = a, b
          end

          [a, b]
        end

        def prepare_input(source)
          if source.is_a?(Integer)
            Value.new(source)
          elsif register?(source)
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
