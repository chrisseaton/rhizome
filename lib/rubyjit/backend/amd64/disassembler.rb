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

      # An disassembler produces text assembly code for machine code bytes.
      
      class Disassembler
        
        def initialize(bytes)
          @bytes = bytes
          @pos = 0
        end
        
        def more?
          @pos < @bytes.size
        end
        
        def next
          @start = @pos
          text = read
          address = '0x' + @start.to_s(16).rjust(16, '0')
          bytes = '0x' + @bytes[@start...@pos].map { |b| b.to_s(16).rjust(2, '0') }.join
          address + '  ' + text.ljust(29) + ' ; ' + bytes
        end

        private

        def read
          byte = shift

          prefix = nil

          if [REXB, REXW].include?(byte)
            prefix = byte
            byte = shift
          end

          if byte == 0xc3
            insn = 'ret'
          elsif byte == 0x90
            insn = 'nop'
          elsif byte == 0xe9
            insn = "jmp #{shift_sint32}"
          elsif byte == 0x0f
            name = case shift & ~0x80
                     when EQUAL;         'e'
                     when NOT_EQUAL;     'ne'
                     when LESS;          'lt'
                     when LESS_EQUALS;   'le'
                     when GREATER;       'gt'
                     when GREATER_EQUAL; 'ge'
                     when OVERFLOW;       'o'
                     else;                raise
                   end
            insn = "j#{name} #{shift_sint32}"
          elsif byte & 0xf8 == 0x50
            insn = "push #{register(prefix, byte & 0x7)}"
          elsif byte & 0xf8 == 0x58
            insn = "pop #{register(prefix, byte & 0x7)}"
          elsif byte == 0x01
            raise unless prefix == REXW
            byte = shift
            insn = "add #{register((byte >> 3) & 0x7)} #{register(byte & 0x7)}"
          elsif byte == 0x21
            raise unless prefix == REXW
            byte = shift
            insn = "and #{register((byte >> 3) & 0x7)} #{register(byte & 0x7)}"
          elsif byte == 0x39
            raise unless prefix == REXW
            byte = shift
            insn = "cmp #{register((byte >> 3) & 0x7)} #{register(byte & 0x7)}"
          elsif byte == 0xd3
            raise unless prefix == REXW
            byte = shift
            name = case byte & 0xe8
                     when 0xe8;   'r'
                     when 0xe0;   'l'
                     else;        raise
                   end
            insn = "sh#{name} %cl #{register(prefix, byte & 0x7)}"
          elsif [0x89, 0x8b].include?(byte)
            raise unless prefix == REXW
            next_byte = shift
            r1 = register((next_byte >> 3) & 0x7)
            r2 = register(next_byte & 0x7)
            if (next_byte & 0b11000000) == 0b01000000
              offset = shift
              offset -= 256 if (offset & 0x80) == 0x80
              if offset.positive?
                r2 += '+'
              else
                r2 += '-'
                offset = -offset
              end
              r2 += '0x'
              r2 += offset.to_s(16)
            end
            if byte == 0x89
              source, dest = r1, r2
            else
              dest, source = r1, r2
            end
            insn = "mov #{source} #{dest}"
          elsif byte == 0xb8
            dest = register(byte & 0x7)
            if prefix == REXW
              value = shift_sint64
            else
              value = shift_sint32
            end
            insn = "mov 0x#{value.to_s(16)} #{dest}"
          end

          insn = "data 0x#{byte.to_s(16).rjust(2, '0')}" unless insn

          insn
        end

        def register(prefix=nil, encoding)
          encoding += 8 if prefix == REXB
          '%' + REGISTERS.find { |r| r.encoding == encoding }.name.to_s.downcase
        end
        
        def shift
          byte = @bytes[@pos]
          @pos += 1
          byte
        end

        def shift_sint32
          4.times.map{ shift }.pack('c*').unpack('l<').first
        end

        def shift_sint64
          8.times.map{ shift }.pack('c*').unpack('q<').first
        end
        
      end
      
    end
  end
end
