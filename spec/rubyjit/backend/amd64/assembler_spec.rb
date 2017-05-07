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

describe RubyJIT::Backend::AMD64::Assembler do

  before :each do
    @assembler = RubyJIT::Backend::AMD64::Assembler.new
  end

  describe '#push' do

    it 'correctly assembles low registers' do
      @assembler.push RubyJIT::Backend::AMD64::RBP
      expect(@assembler.bytes).to eql [0x55]
    end

    it 'correctly assembles high registers' do
      @assembler.push RubyJIT::Backend::AMD64::R15
      expect(@assembler.bytes).to eql [0x41, 0x57]
    end

    it 'handles all registers' do
      RubyJIT::Backend::AMD64::REGISTERS.each do |r|
        @assembler.push r
      end
    end

  end

  describe '#pop' do

    it 'correctly assembles low registers' do
      @assembler.pop RubyJIT::Backend::AMD64::RBP
      expect(@assembler.bytes).to eql [0x5d]
    end

    it 'correctly assembles high registers' do
      @assembler.pop RubyJIT::Backend::AMD64::R15
      expect(@assembler.bytes).to eql [0x41, 0x5f]
    end

    it 'handles all registers' do
      RubyJIT::Backend::AMD64::REGISTERS.each do |r|
        @assembler.pop r
      end
    end

  end

  describe '#mov' do

    it 'correctly assembles register to register' do
      @assembler.mov RubyJIT::Backend::AMD64::RSP, RubyJIT::Backend::AMD64::RBP
      expect(@assembler.bytes).to eql [0x48, 0x89, 0xe5]
    end

    it 'correctly assembles address to register' do
      @assembler.mov RubyJIT::Backend::AMD64::RSP + 10, RubyJIT::Backend::AMD64::RBP
      expect(@assembler.bytes).to eql [0x48, 0x8b, 0x6c, 0x0a]
    end

    it 'correctly assembles register to address' do
      @assembler.mov RubyJIT::Backend::AMD64::RSP, RubyJIT::Backend::AMD64::RBP + 10
      expect(@assembler.bytes).to eql [0x48, 0x89, 0x65, 0x0a]
    end

    it 'handles all low registers' do
      RubyJIT::Backend::AMD64::LOW_REGISTERS.each do |r1|
        RubyJIT::Backend::AMD64::LOW_REGISTERS.each do |r2|
          @assembler.mov r1, r2
        end
      end
    end

  end

  describe '#add' do

    it 'correctly assembles' do
      @assembler.add RubyJIT::Backend::AMD64::RSP, RubyJIT::Backend::AMD64::RBP
      expect(@assembler.bytes).to eql [0x48, 0x01, 0xe5]
    end

    it 'handles all low registers' do
      RubyJIT::Backend::AMD64::LOW_REGISTERS.each do |r1|
        RubyJIT::Backend::AMD64::LOW_REGISTERS.each do |r2|
          @assembler.add r1, r2
        end
      end
    end

  end

  describe '#ret' do

    it 'correctly assembles' do
      @assembler.ret
      expect(@assembler.bytes).to eql [0xc3]
    end

  end

end
