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

module Rhizome
  module Backend
    module AMD64

      # An disassembler produces text assembly code for machine code bytes.
      
      class Disassembler
        
        def initialize(bytes, installed_location=0)
          @bytes = bytes
          @pos = 0
          @installed_location = installed_location
        end
        
        def more?
          @pos < @bytes.size
        end
        
        def next
          @start = @pos
          text = read
          address = '0x' + (@start + @installed_location).to_s(16).rjust(16, '0')
          bytes = @bytes[@start...@pos].map { |b| b.to_s(16).rjust(2, '0') }.join(' ')
          address + '  ' + text.ljust(29) + ' ; ' + bytes
        end

        private

        def read
          byte = shift

          if PREFIXES.include?(byte)
            prefix = byte
            byte = shift
          else
            prefix = nil
          end

          if byte == 0xc3
            insn = 'ret'
          elsif byte == 0xff
            target = shift
            if target & 0xd0 == 0xd0
              insn = "call *#{register(prefix, target & ~0xd0)}"
            end
          elsif byte == 0x90
            insn = 'nop'
          elsif byte == 0xcc
            insn = 'int 3'
          elsif byte == 0xe9
            offset = shift_sint32
            target = @installed_location + @start + 5 + offset
            insn = "jmp #{offset} (0x#{target.to_s(16).rjust(16, '0')})"
          elsif byte == 0x0f
            byte = shift
            if byte == 0xaf
              byte = shift
              source, dest = decode_prefix_and_registers(prefix, byte, true, true)
              insn = "imul #{source} #{dest}"
            else
              name = case byte & ~0x80
                       when EQUAL;         'e'
                       when NOT_EQUAL;     'ne'
                       when LESS;          'lt'
                       when LESS_EQUALS;   'le'
                       when GREATER;       'gt'
                       when GREATER_EQUAL; 'ge'
                       when OVERFLOW;      'o'
                       else;                raise
                     end
              offset = shift_sint32
              target = @installed_location + @start + 6 + offset
              insn = "j#{name} #{offset} (0x#{target.to_s(16).rjust(16, '0')})"
            end
          elsif byte & 0xf8 == 0x50
            insn = "push #{register(prefix, byte & 0x7)}"
          elsif byte & 0xf8 == 0x58
            insn = "pop #{register(prefix, byte & 0x7)}"
          elsif byte == 0x01
            byte = shift
            source, dest = decode_prefix_and_registers(prefix, byte, true)
            insn = "add #{source} #{dest}"
          elsif byte == 0x29
            byte = shift
            source, dest = decode_prefix_and_registers(prefix, byte, true)
            insn = "sub #{source} #{dest}"
          elsif byte == 0x21
            byte = shift
            source, dest = decode_prefix_and_registers(prefix, byte, true)
            insn = "and #{source} #{dest}"
          elsif byte == 0x39
            byte = shift
            source, dest = decode_prefix_and_registers(prefix, byte, true)
            insn = "cmp #{source} #{dest}"
          elsif byte == 0xd3
            byte = shift
            name = case byte & 0xe8
                     when 0xe8;   'r'
                     when 0xe0;   'l'
                     else;        raise
                   end
            dest, _ = decode_prefix_and_registers(prefix, byte)
            insn = "sh#{name} %cl #{dest}"
          elsif [0x89, 0x8b].include?(byte)
            next_byte = shift
            r1, r2 = decode_prefix_and_registers(prefix, next_byte, true)
            if (next_byte & 0b11000000) == 0b01000000
              offset = shift
              offset -= 256 if (offset & 0x80) == 0x80
              if offset.negative?
                r2 += '-'
                offset = -offset
              else
                r2 += '+'
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
          elsif byte & 0xf8 == 0xb8
            dest = register(prefix, byte & 0x7)
            if [REXW, REXWB].include?(prefix)
              value = shift_sint64
            else
              value = shift_sint32
            end
            if value.negative?
              value = "-0x#{-value.to_s(16)}"
            else
              value = "0x#{value.to_s(16)}"
            end
            insn = "mov #{value} #{dest}"
          end

          insn = "data 0x#{byte.to_s(16).rjust(2, '0')}" unless insn

          insn
        end

        def register(prefix=nil, encoding)
          encoding += 8 if [REXB, REXWB].include?(prefix)
          '%' + REGISTERS.find { |r| r.encoding == encoding }.name.to_s.downcase
        end

        def decode_prefix_and_registers(prefix, encoded, two=false, reverse=false)
          if two
            source = (encoded >> 3) & 0x7
            dest = encoded & 0x7
            case prefix
              when REXW
              when REXWB
                dest += 8
              when REXWR
                source += 8
              when REXWRB
                source += 8
                dest += 8
              else
                raise
            end
            source, dest = dest, source if reverse
          else
            source = encoded & 0x7
            dest = nil
            case prefix
              when REXW
              when REXWB
                source += 8
              else
                raise
            end
          end
          source = '%' + REGISTERS.find { |r| r.encoding == source }.name.to_s.downcase
          dest = '%' + REGISTERS.find { |r| r.encoding == dest }.name.to_s.downcase if dest
          [source, dest]
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
