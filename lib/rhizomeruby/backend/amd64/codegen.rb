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
          # Find out what registers will have arguments in them that we use and so need to be preserved during calls

          arg_registers = Set.new

          blocks.each do |block|
            block.each do |insn|
              case insn.first
                when :self
                  arg_registers.add source_for_arg(:self)
                when :arg
                  _, n, _ = insn
                  arg_registers.add source_for_arg(n)
              end
            end
          end

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

          space_needed = max_slot + 8

          # Frame sizes need to be aligned to 16 bytes.

          frame_size = space_needed + space_needed % 16

          # Standard AMD64 function prelude - preserve the caller's rbp and create our stack space.

          @assembler.push RBP
          @assembler.mov RSP, RBP

          @assembler.mov Value.new(frame_size), RAX
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
                  @assembler.mov source_for_arg(:self), operand(dest)
                when :arg
                  _, n, dest = insn
                  @assembler.mov source_for_arg(n), operand(dest)
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

                  preserve = arg_registers.union([RDI, RSI])

                  # The frame still has to be aligned on 16 bytes when we make the call so do we just push an extra
                  # dummy value if there aren't enough values to have it aligned naturally? The basic frame is already
                  # aligned on 16 bytes.

                  receiver_and_name = 2
                  to_push = preserve.size + args.size + receiver_and_name
                  @assembler.push RAX if to_push % 2 == 1

                  # Preserve registers that we'll overwrite

                  preserve.each do |r|
                    @assembler.push r
                  end

                  args.reverse.each do |arg|
                    @assembler.mov operand(arg), RAX
                    @assembler.push RAX
                  end

                  # Push the method name and the receiver.

                  @assembler.mov operand(name), RAX
                  @assembler.push RAX
                  @assembler.mov operand(receiver), RAX
                  @assembler.push RAX

                  # The first argument is then the current stack pointer, and the second is the number of arguments.

                  @assembler.mov RSP, RDI
                  @assembler.mov Value.new(args.size), RSI

                  # Call into managed.

                  @assembler.mov Value.new(@interface.call_managed_address), RAX
                  @assembler.call Indirection.new(RAX)
                  @assembler.mov RAX, operand(target)

                  # Pop args back off.

                  (args.size + 2).times do
                    @assembler.pop RAX
                  end

                  # Restore registers that we rpreserved

                  preserve.to_a.reverse.each do |r|
                    @assembler.pop r
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
            @assembler.mov Handle.new(deopt.frame_state), RDX
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
