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

describe RubyJIT::Backend::AMD64::Disassembler do

  before :each do
    @assembler = RubyJIT::Backend::AMD64::Assembler.new

    @disassemble = proc {
      @disassembler = RubyJIT::Backend::AMD64::Disassembler.new(@assembler.bytes)
    }
  end

  describe '#read' do

    describe 'correctly disassembles' do

      describe 'push' do

        it 'with low registers' do
          @assembler.push RubyJIT::Backend::AMD64::RBP
          @disassemble.call
          expect(@disassembler.next).to eql '0x0000000000000000  push %rbp                     ; 0x55'
        end

        it 'with high registers' do
          @assembler.push RubyJIT::Backend::AMD64::R15
          @disassemble.call
          expect(@disassembler.next).to eql '0x0000000000000000  push %r15                     ; 0x4157'
        end

      end

      describe 'pop' do

        it 'with low registers' do
          @assembler.pop RubyJIT::Backend::AMD64::RBP
          @disassemble.call
          expect(@disassembler.next).to eql '0x0000000000000000  pop %rbp                      ; 0x5d'
        end

        it 'with high registers' do
          @assembler.pop RubyJIT::Backend::AMD64::R15
          @disassemble.call
          expect(@disassembler.next).to eql '0x0000000000000000  pop %r15                      ; 0x415f'
        end

      end

      describe 'mov' do

        it 'register to register' do
          @assembler.mov RubyJIT::Backend::AMD64::RSP, RubyJIT::Backend::AMD64::RBP
          @disassemble.call
          expect(@disassembler.next).to eql '0x0000000000000000  mov %rsp %rbp                 ; 0x4889e5'
        end

        it 'address to register' do
          @assembler.mov RubyJIT::Backend::AMD64::RSP + 10, RubyJIT::Backend::AMD64::RBP
          @disassemble.call
          expect(@disassembler.next).to eql '0x0000000000000000  mov %rsp+0xa %rbp             ; 0x488b6c0a'
        end

        it 'register to address' do
          @assembler.mov RubyJIT::Backend::AMD64::RSP, RubyJIT::Backend::AMD64::RBP + 10
          @disassemble.call
          expect(@disassembler.next).to eql '0x0000000000000000  mov %rsp %rbp+0xa             ; 0x4889650a'
        end

        it 'small value to register' do
          @assembler.mov RubyJIT::Backend::AMD64::Value.new(14), RubyJIT::Backend::AMD64::RAX
          @disassemble.call
          expect(@disassembler.next).to eql '0x0000000000000000  mov 0xe %rax                  ; 0xb80e000000'
        end

        it 'big value to register' do
          @assembler.mov RubyJIT::Backend::AMD64::Value.new(0x1234567812345678), RubyJIT::Backend::AMD64::RAX
          @disassemble.call
          expect(@disassembler.next).to eql '0x0000000000000000  mov 0x1234567812345678 %rax   ; 0x48b87856341278563412'
        end

        it 'with negative offsets' do
          @assembler.mov RubyJIT::Backend::AMD64::RSP, RubyJIT::Backend::AMD64::RBP - 10
          @disassemble.call
          expect(@disassembler.next).to eql '0x0000000000000000  mov %rsp %rbp-0xa             ; 0x488965f6'
        end

      end

      describe 'add' do

        it 'register to register' do
          @assembler.add RubyJIT::Backend::AMD64::RSP, RubyJIT::Backend::AMD64::RBP
          @disassemble.call
          expect(@disassembler.next).to eql '0x0000000000000000  add %rsp %rbp                 ; 0x4801e5'
        end

      end

      it 'shr' do
        @assembler.shr RubyJIT::Backend::AMD64::RCX, RubyJIT::Backend::AMD64::RAX
        @disassemble.call
        expect(@disassembler.next).to eql '0x0000000000000000  shr %cl %rax                  ; 0x48d3e8'
      end

      it 'shl' do
        @assembler.shl RubyJIT::Backend::AMD64::RCX, RubyJIT::Backend::AMD64::RAX
        @disassemble.call
        expect(@disassembler.next).to eql '0x0000000000000000  shl %cl %rax                  ; 0x48d3e0'
      end

      it 'cmp' do
        @assembler.cmp RubyJIT::Backend::AMD64::RAX, RubyJIT::Backend::AMD64::RCX
        @disassemble.call
        expect(@disassembler.next).to eql '0x0000000000000000  cmp %rax %rcx                 ; 0x4839c1'
      end

      it 'jmp with a backward jump' do
        head = @assembler.label
        @assembler.jmp head
        @disassemble.call
        expect(@disassembler.next).to eql '0x0000000000000000  jmp -5                        ; 0xe9fbffffff'
      end

      it 'jmp with a backward jump over another instruction' do
        head = @assembler.label
        @assembler.nop
        @assembler.jmp head
        @disassemble.call
        expect(@disassembler.next).to eql '0x0000000000000000  nop                           ; 0x90'
        expect(@disassembler.next).to eql '0x0000000000000001  jmp -6                        ; 0xe9faffffff'
      end

      it 'jmp with a forward jump' do
        head = @assembler.jmp
        @assembler.label head
        @disassemble.call
        expect(@disassembler.next).to eql '0x0000000000000000  jmp 0                         ; 0xe900000000'
      end

      it 'jmp with a forward jump over another instruction' do
        head = @assembler.jmp
        @assembler.nop
        @assembler.label head
        @disassemble.call
        expect(@disassembler.next).to eql '0x0000000000000000  jmp 1                         ; 0xe901000000'
      end

      it 'je with a backward jump' do
        head = @assembler.label
        @assembler.je head
        @disassemble.call
        expect(@disassembler.next).to eql '0x0000000000000000  je -6                         ; 0x0f84faffffff'
      end

      it 'jne with a backward jump' do
        head = @assembler.label
        @assembler.jne head
        @disassemble.call
        expect(@disassembler.next).to eql '0x0000000000000000  jne -6                        ; 0x0f85faffffff'
      end

      it 'ret' do
        @assembler.ret
        @disassemble.call
        expect(@disassembler.next).to eql '0x0000000000000000  ret                           ; 0xc3'
      end

      it 'nop' do
        @assembler.nop
        @disassemble.call
        expect(@disassembler.next).to eql '0x0000000000000000  nop                           ; 0x90'
      end

      it 'unknown data' do
        @assembler.send :emit, 0x00
        @disassemble.call
        expect(@disassembler.next).to eql '0x0000000000000000  data 0x00                     ; 0x00'
      end

    end

  end

end
