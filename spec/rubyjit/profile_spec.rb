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

describe RubyJIT::Profile do

  before :each do
    @interpreter = RubyJIT::Interpreter.new
    @profile = RubyJIT::Profile.new
    @interpreter.interpret(RubyJIT::Fixtures::FIB_BYTECODE_RUBYJIT, RubyJIT::Fixtures, [10], @profile)
  end

  describe '#sends' do

    it 'returns an array of send profiles' do
      @profile.sends.each do |ip, send|
        expect(ip).to be_an(Integer)
        expect(send).to be_a(RubyJIT::Profile::SendProfile)
      end
    end
    
    describe 'for a fib function' do
      
      it 'correctly gathers profiling information for send instructions' do
        send = @profile.sends[6]
        expect(send.receiver_kinds).to contain_exactly(:fixnum)
        expect(send.args_kinds.size).to eql 1
        expect(send.args_kinds[0]).to contain_exactly(:fixnum)
        
        send = @profile.sends[16]
        expect(send.receiver_kinds).to contain_exactly(:fixnum)
        expect(send.args_kinds.size).to eql 1
        expect(send.args_kinds[0]).to contain_exactly(:fixnum)
        
        send = @profile.sends[17]
        expect(send.receiver_kinds).to contain_exactly(Object)
        expect(send.args_kinds.size).to eql 1
        expect(send.args_kinds[0]).to contain_exactly(:fixnum)
        
        send = @profile.sends[21]
        expect(send.receiver_kinds).to contain_exactly(:fixnum)
        expect(send.args_kinds.size).to eql 1
        expect(send.args_kinds[0]).to contain_exactly(:fixnum)
        
        send = @profile.sends[22]
        expect(send.receiver_kinds).to contain_exactly(Object)
        expect(send.args_kinds.size).to eql 1
        expect(send.args_kinds[0]).to contain_exactly(:fixnum)
        
        send = @profile.sends[23]
        expect(send.receiver_kinds).to contain_exactly(:fixnum)
        expect(send.args_kinds.size).to eql 1
        expect(send.args_kinds[0]).to contain_exactly(:fixnum)
      end
      
    end

  end

end
