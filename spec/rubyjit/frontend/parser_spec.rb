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

require 'rubyjit'

require_relative '../fixtures'

describe RubyJIT::Frontend::MRIParser do

  before :each do
    @parser = RubyJIT::Frontend::MRIParser.new
  end

  if RubyJIT::Config::MRI

    describe '.text_for' do

      it 'returns the text for the bytecode for an add method' do
        expect(@parser.text_for(RubyJIT::Fixtures.method(:add))).to be == RubyJIT::Fixtures::ADD_BYTECODE_MRI
      end

      it 'returns the text for the bytecode for a fib method' do
        expect(@parser.text_for(RubyJIT::Fixtures.method(:fib))).to be == RubyJIT::Fixtures::FIB_BYTECODE_MRI
      end

    end

  end

  describe '.parse' do

    it 'parses the text for an add method' do
      expect(@parser.parse(RubyJIT::Fixtures::ADD_BYTECODE_MRI)).to be == RubyJIT::Fixtures::ADD_BYTECODE_RUBYJIT
    end

    it 'parses the text for a fib method' do
      expect(@parser.parse(RubyJIT::Fixtures::FIB_BYTECODE_MRI)).to be == RubyJIT::Fixtures::FIB_BYTECODE_RUBYJIT
    end

  end

end

describe RubyJIT::Frontend::RbxParser do

  before :each do
    @parser = RubyJIT::Frontend::RbxParser.new
  end

  if RubyJIT::Config::RBX

    describe '.text_for' do

      it 'returns the text for the bytecode for an add method' do
        expect(@parser.text_for(RubyJIT::Fixtures.method(:add))).to be == RubyJIT::Fixtures::ADD_BYTECODE_RBX
      end

      it 'returns the text for the bytecode for a fib method' do
        expect(@parser.text_for(RubyJIT::Fixtures.method(:fib))).to be == RubyJIT::Fixtures::FIB_BYTECODE_RBX
      end

    end

  end

  describe '.parse' do

    # The bytecode from the Rubinius parser doesn't have trace instructions, so mask_traces removes them and
    # normalises branch offsets to 0.

    it 'parses the text for an add method' do
      expect(RubyJIT::Fixtures.mask_traces(@parser.parse(RubyJIT::Fixtures::ADD_BYTECODE_RBX)))
          .to be == RubyJIT::Fixtures.mask_traces(RubyJIT::Fixtures::ADD_BYTECODE_RUBYJIT)
    end

    it 'parses the text for a fib method' do
      expect(RubyJIT::Fixtures.mask_traces(@parser.parse(RubyJIT::Fixtures::FIB_BYTECODE_RBX)))
          .to be == RubyJIT::Fixtures.mask_traces(RubyJIT::Fixtures::FIB_BYTECODE_RUBYJIT)
    end

  end

end

describe RubyJIT::Frontend::JRubyParser do

  before :each do
    @parser = RubyJIT::Frontend::JRubyParser.new
  end

  if RubyJIT::Config::JRUBY

    describe '.text_for' do

      it 'returns the text for the bytecode for an add method' do
        expect(@parser.text_for(RubyJIT::Fixtures.method(:add))).to be == RubyJIT::Fixtures::ADD_BYTECODE_JRUBY
      end

      it 'returns the text for the bytecode for a fib method' do
        expect(@parser.text_for(RubyJIT::Fixtures.method(:fib))).to be == RubyJIT::Fixtures::FIB_BYTECODE_JRUBY
      end

    end

  end

  describe '.parse' do

    # We have separate expected bytecode for JRuby as JRuby's format uses registers

    it 'parses the text for an add method' do
      expect(@parser.parse(RubyJIT::Fixtures::ADD_BYTECODE_JRUBY)).to be == RubyJIT::Fixtures::ADD_BYTECODE_RUBYJIT_FROM_JRUBY
    end

    it 'parses the text for a fib method' do
      expect(@parser.parse(RubyJIT::Fixtures::FIB_BYTECODE_JRUBY)).to be == RubyJIT::Fixtures::FIB_BYTECODE_RUBYJIT_FROM_JRUBY
    end

  end

end
