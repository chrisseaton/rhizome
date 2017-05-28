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
  module Backend
    module AMD64

      # A register in the AMD64 instruction set architecture.

      class Register

        attr_reader :name, :encoding

        def initialize(name, encoding)
          @name = name
          @encoding = encoding
        end

        def -(offset)
          self + -offset
        end

        def +(offset)
          Address.new(self, offset)
        end

        def prefix_and_encoding
          if encoding >= 8
            [REXB, encoding - 8]
          else
            [nil, encoding]
          end
        end

      end

      # A combination of a base register and an offset.

      Address = Struct.new(:base, :offset)

      # An absolute value.

      Value = Struct.new(:value)

      # A handle to a Ruby object.

      Handle = Struct.new(:object)
      
      # Indirection of something else.
      
      Indirection = Struct.new(:base)

      # Create constants for all registers available.

      REGISTERS = [:RAX, :RCX, :RDX, :RBX, :RSP, :RBP, :RSI, :RDI,
                   :R8,  :R9,  :R10, :R11, :R12, :R13, :R14, :R15].map.with_index { |name, encoding|
        Register.new(name, encoding)
      }

      REGISTERS.each do |r|
        const_set r.name, r
      end

      # For testing purposes, list those that are simpler to encode.

      LOW_REGISTERS = REGISTERS.select { |r| r.encoding < 8 }

      # Prefixes are part of the AMD64 encoding system.

      [:REX,    :REXB,
       :REXX,   :REXXB,
       :REXR,   :REXRB,
       :REXRX,  :REXRXB,
       :REXW,   :REXWB,
       :REXWX,  :REXWXB,
       :REXWR,  :REXWRB,
       :REXWRX, :REXWRXB].each_with_index do |name, encoding|
        const_set name, 0x40 + encoding
      end

      # Condition flags.

      EQUAL         = 0x4
      NOT_EQUAL     = 0x5
      LESS          = 0xc
      LESS_EQUALS   = 0xe
      GREATER       = 0xf
      GREATER_EQUAL = 0xd
      OVERFLOW      = 0x0

      # An assembler emits machine code bytes for given assembly instructions.

      class Assembler

        attr_reader :bytes
        attr_reader :references

        def initialize(handles=nil)
          @handles = handles
          @bytes = []
          @references = []
        end

        # We won't comment on how the encoding works, as it isn't unique or
        # particularly interesting for what Rhizome is designed to illustrate.
        # For each instruction there's a method and that method appends some
        # more bytes onto the array.

        def push(source)
          prefix, encoding = source.prefix_and_encoding
          emit prefix if prefix
          emit 0x50 | encoding
        end

        def mov(source, dest)
          if source.is_a?(Handle)
            reference source.object
            source = Value.new(@handles.to_native(source.object))
          end

          if source.is_a?(Register) && dest.is_a?(Register)
            raise if source.encoding >= 8
            raise if dest.encoding >= 8
            emit REXW, 0x89, 0b11000000 | (source.encoding << 3) | dest.encoding
          elsif source.is_a?(Address) && dest.is_a?(Register)
            raise if source.base.encoding >= 8
            raise if dest.encoding >= 8
            if source.offset >= -127 || source.offset <= 128
              emit REXW, 0x8b, 0b01000000 | (dest.encoding << 3) | source.base.encoding, source.offset
            else
              raise
            end
          elsif source.is_a?(Register) && dest.is_a?(Address)
            raise if source.encoding >= 8
            raise if dest.base.encoding >= 8
            if dest.offset >= -127 || dest.offset <= 128
              emit REXW, 0x89, 0b01000000 | (source.encoding << 3) | dest.base.encoding, dest.offset
            else
              raise
            end
          elsif source.is_a?(Value) && dest.is_a?(Register)
            raise if dest.encoding >= 8
            if source.value >= -2147483648 && source.value <= 2147483647
              emit 0b10111000 | dest.encoding
              emit_sint32 source.value
            else
              emit REXW
              emit 0b10111000 | dest.encoding
              emit_sint64 source.value
            end
          else
            raise
          end
        end

        def add(source, dest)
          if source.is_a?(Register) && dest.is_a?(Register)
            raise if source.encoding >= 8
            raise if dest.encoding >= 8
            emit REXW, 0x01, 0b11000000 | (source.encoding << 3) | dest.encoding
          else
            raise
          end
        end

        def sub(source, dest)
          if source.is_a?(Register) && dest.is_a?(Register)
            raise if source.encoding >= 8
            raise if dest.encoding >= 8
            emit REXW, 0x29, 0b11000000 | (source.encoding << 3) | dest.encoding
          else
            raise
          end
        end

        def imul(source, dest)
          if source.is_a?(Register) && dest.is_a?(Register)
            raise if source.encoding >= 8
            raise if dest.encoding >= 8
            emit REXW, 0x0f, 0xaf, 0b11000000 | (dest.encoding << 3) | source.encoding
          else
            raise
          end
        end

        def and(source, dest)
          if source.is_a?(Register) && dest.is_a?(Register)
            raise if source.encoding >= 8
            raise if dest.encoding >= 8
            emit REXW, 0x21, 0b11000000 | (source.encoding << 3) | dest.encoding
          else
            raise
          end
        end

        def shr(shift, register)
          raise unless shift == RCX
          emit REXW, 0xd3, 0xe8 | register.encoding
        end

        def shl(shift, register)
          raise unless shift == RCX
          emit REXW, 0xd3, 0xe0 | register.encoding
        end

        def pop(dest)
          prefix, encoding = dest.prefix_and_encoding
          emit prefix if prefix
          emit 0x58 | encoding
        end

        def cmp(a, b)
          if a.is_a?(Register) && b.is_a?(Register)
            raise if a.encoding >= 8
            raise if b.encoding >= 8
            emit REXW, 0x39, 0b11000000 | (a.encoding << 3) | b.encoding
          else
            raise
          end
        end
        
        def jmp(label=nil)
          jcc(nil, label)
        end

        def je(label=nil)
          jcc(EQUAL, label)
        end

        def jne(label=nil)
          jcc(NOT_EQUAL, label)
        end

        def jcc(condition, label)
          label = General::Label.new(self) unless label

          if condition
            emit 0x0f
            emit 0x80 | condition
          else
            emit 0xe9
          end

          # Does this label already have a location?

          if label.marked?
            # If it does, emit the offset to that location.
            emit_sint32 label.location - location - 4
          else
            # If it doesn't, remember that we want to patch this location in the
            # future and emit 0s for now.
            label.patch_point location + 4
            emit 0x00
            emit 0x00
            emit 0x00
            emit 0x00
          end

          label
        end
        
        def label(label=nil)
          label = General::Label.new(self) unless label
          label.mark
          label
        end

        def nop
          emit 0x90
        end

        def int(code)
          raise unless code == 3
          emit 0xcc
        end
        
        def call(dest)
          if dest.is_a?(Indirection)
            if dest.base.is_a?(Register)
              emit 0xff
              emit 0xd0 | dest.base.encoding
            else
              raise
            end
          else
            raise
          end
        end

        def ret
          emit 0xc3
        end

        def location
          bytes.size
        end

        def patch(location, value)
          bytes[location...location+4] = [value].pack('l<').bytes
        end

        def reference(object)
          @references.push object
        end
        
        private

        def emit(*values)
          values.each do |v|
            bytes.push v & 0xff
          end
        end

        def emit_sint32(value)
          emit *[value].pack('l<').bytes
        end

        def emit_sint64(value)
          emit *[value].pack('q<').bytes
        end

      end

    end
  end
end
