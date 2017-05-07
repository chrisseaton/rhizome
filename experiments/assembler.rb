# Copyright (c) 2016-2017 Chris Seaton
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

# Illustrates using the AM64 assembler directly.

require_relative '../lib/rubyjit'

raise 'this experiment only works on AMD64' unless RubyJIT::Config::AMD64

include RubyJIT::Backend::AMD64

assembler = Assembler.new

# We'll compile a simple add function, but we'll store the arguments in local
# variables even though we could add them without doing that, so that we can
# demonstrate reading and writing from the stack.

assembler.push RBP              # Store the caller's frame address

assembler.mov  RSP, RBP         # Store the address of the frame in %rbp

assembler.mov  RDI, RBP - 0x8   # Store the first argument on the stack
assembler.mov  RSI, RBP - 0x10  # Store the second argument on the stack

assembler.mov  RBP - 0x8, RAX   # Read the first argument back from the stack
assembler.mov  RBP - 0x10, RCX  # Read the second argument back from the stack

assembler.add  RCX, RAX         # Add the second argument into the first

assembler.pop  RBP              # Restore the caller's frame address

assembler.ret                   # Return

machine_code = assembler.bytes

puts 'Assembled machine code:'
puts

machine_code.each_slice(8) do |row|
  row.each do |b|
    print b.to_s(16).rjust(2, '0')
  end
  puts
end

puts

memory = RubyJIT::Memory.new(machine_code.size)
memory.write 0, machine_code
memory.executable = true
native_method = memory.to_proc([:long, :long], :long)

puts 'Calling:'
puts

puts native_method.call(14, 2)
