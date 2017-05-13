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
          bytes = '0x' + @bytes[@start...@pos].map { |b| b.to_s(16).rjust(2, '0') }.join.ljust(10)
          address + '  ' + text.ljust(20) + ' ; ' + bytes
        end

        private

        def read
          byte = shift

          prefix = nil

          if byte == REXB
            prefix = byte
            byte = shift
          end

          if byte == 0xc3
            insn = 'ret'
          elsif byte == 0x90
            insn = 'nop'
          elsif byte & 0xf8 == 0x50
            insn = "push #{register(prefix, byte & 0x7)}"
          elsif byte & 0xf8 == 0x58
            insn = "pop #{register(prefix, byte & 0x7)}"
          elsif byte == 0x48
            byte = shift
            if [0x89, 0x8b].include?(byte)
              next_byte = shift
              r1 = register((next_byte >> 3) & 0x7)
              r2 = register(next_byte & 0x7)
              if (next_byte & 0b11000000) == 0b01000000
                offset = shift
                offset -= 256 if (offset & 0x80) == 0x80
                r2 += '+' if offset.positive?
                r2 += offset.to_s
              end
              if byte == 0x89
                source, dest = r1, r2
              else
                dest, source = r1, r2
              end
              insn = "mov #{source} #{dest}"
            elsif byte == 0x01
              byte = shift
              insn = "add #{register((byte >> 3) & 0x7)} #{register(byte & 0x7)}"
            end
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
        
      end
      
    end
  end
end
