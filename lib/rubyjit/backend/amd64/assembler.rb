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
# THE SOFTWARE IS PROVencodingED "AS IS", WITHOUT WARRANTY OF ANY KIND,
# EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
# MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
# NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE
# LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION
# OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION
# WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

module RubyJIT
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

      # An assembler allows machine code instruction bytes to emitted.

      class Assembler

        attr_reader :bytes

        def initialize
          @bytes = []
        end

        # We won't comment on how the encoding works, as it isn't unique or
        # particularly interesting for what RubyJIT is designed to illustrate.
        # For each instruction there's a method and that method appends some
        # more bytes onto the array.

        def push(source)
          prefix, encoding = source.prefix_and_encoding
          emit prefix if prefix
          emit 0x50 | encoding
        end

        def mov(source, dest)
          if source.is_a?(Register) && dest.is_a?(Register)
            raise if source.encoding >= 8
            raise if dest.encoding >= 8
            emit 0x48, 0x89, 0b11000000 | (source.encoding << 3) | dest.encoding
          elsif source.is_a?(Address) && dest.is_a?(Register)
            raise if source.base.encoding >= 8
            raise if source.offset < -127 || source.offset > 128
            raise if dest.encoding >= 8
            emit 0x48, 0x8b, 0b01000000 | (dest.encoding << 3) | source.base.encoding, source.offset
          elsif source.is_a?(Register) && dest.is_a?(Address)
            raise if source.encoding >= 8
            raise if dest.base.encoding >= 8
            raise if dest.offset < -127 || dest.offset > 128
            emit 0x48, 0x89, 0b01000000 | (source.encoding << 3) | dest.base.encoding, dest.offset
          else
            raise
          end
        end

        def add(source, dest)
          if source.is_a?(Register) && dest.is_a?(Register)
            raise if source.encoding >= 8
            raise if dest.encoding >= 8
            emit 0x48, 0x01, 0b11000000 | (source.encoding << 3) | dest.encoding
          else
            raise
          end
        end

        def pop(dest)
          prefix, encoding = dest.prefix_and_encoding
          emit prefix if prefix
          emit 0x58 | encoding
        end

        def ret
          emit 0xc3
        end
        
        private

        def emit(*values)
          bytes.push *(values.map { |b| b & 0xff })
        end

      end

    end
  end
end
