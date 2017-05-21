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

require 'rubyjit'

require_relative 'fixtures'

describe RubyJIT::Interface do

  before :each do
    @handles = RubyJIT::Handles.new(RubyJIT::Config::WORD_BITS)
    @interface = RubyJIT::Interface.new(@handles)
    @c = @interface.call_managed_address
    
    if RubyJIT::Config::AMD64
      @machine_code = [
        0x52,                   # push rdx      push the argument
        0x56,                   # push rsi      push the method name
        0x57,                   # push rdi      push the receiver
        0x48, 0x89, 0xe7,       # mov rdi rsp   rdi = the address of last value we pushed
        0x48, 0xc7, 0xc6, 0x01, 0x00, 0x00, 0x00,
                                # mov 1 rsi     rsi = the number of arguments
        0x48, 0xb8, *[@c].pack('Q<').bytes,
                                # mov ... rax   rax = the address of the call to managed
        0xff, 0xd0,             # call *rax     call to managed
        0x5b,                   # pop rbx       pop the receiver
        0x5b,                   # pop rbx       pop the method name
        0x5b,                   # pop rbx       pop the argument
        0xc3                    # return
      ]
    else
      pending 'no machine code sample for this architecture'
    end

    @memory = RubyJIT::Memory.new(@machine_code.size)
    @memory.write 0, @machine_code
    @memory.executable = true
    @native_method = @memory.to_proc([:long, :long, :long], :long)
    
    @foo = Object.new
        
    def @foo.bar(n)
      n * 2
    end
  end

  it 'facilitates calls into native and back into Ruby' do
    expect(@interface.call_native(@native_method, 14, :+, 2)).to eq 16
    expect(@interface.call_native(@native_method, 'abc', :[], 1)).to eq 'b'    
    expect(@interface.call_native(@native_method, @foo, :bar, 14)).to eq @foo.bar(14)
  end

end
