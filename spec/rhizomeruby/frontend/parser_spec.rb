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

require 'rhizomeruby'

require_relative '../fixtures'

describe Rhizome::Frontend::MRIParser do

  before :each do
    @parser = Rhizome::Frontend::MRIParser.new
  end

  if Rhizome::Config::MRI

    describe '.text_for' do

      it 'returns the text for the bytecode for an add method' do
        expect(@parser.text_for(Rhizome::Fixtures.method(:add))).to be == Rhizome::Fixtures::ADD_BYTECODE_MRI
      end

      it 'returns the text for the bytecode for a fib method' do
        expect(@parser.text_for(Rhizome::Fixtures.method(:fib))).to be == Rhizome::Fixtures::FIB_BYTECODE_MRI
      end

      it 'returns the text for the bytecode for a compare method' do
        expect(@parser.text_for(Rhizome::Fixtures.method(:compare))).to be == Rhizome::Fixtures::COMPARE_BYTECODE_MRI
      end

      it 'returns the text for the bytecode for a compare method with local variables' do
        expect(@parser.text_for(Rhizome::Fixtures.method(:named_compare))).to be == Rhizome::Fixtures::NAMED_COMPARE_BYTECODE_MRI
      end

      it 'returns the text for the bytecode for a redundant multiply method' do
        expect(@parser.text_for(Rhizome::Fixtures.method(:redundant_multiply))).to be == Rhizome::Fixtures::REDUNDANT_MULTIPLY_BYTECODE_MRI
      end

      it 'returns the text for the bytecode for an add with side effects method' do
        expect(@parser.text_for(Rhizome::Fixtures.method(:add_with_side_effects))).to be == Rhizome::Fixtures::ADD_WITH_SIDE_EFFECTS_BYTECODE_MRI
      end

    end

  end

  describe '.parse' do

    it 'parses the text for an add method' do
      expect(@parser.parse(Rhizome::Fixtures::ADD_BYTECODE_MRI)).to be == Rhizome::Fixtures::ADD_BYTECODE_RHIZOME
    end

    it 'parses the text for a fib method' do
      expect(@parser.parse(Rhizome::Fixtures::FIB_BYTECODE_MRI)).to be == Rhizome::Fixtures::FIB_BYTECODE_RHIZOME
    end

    it 'parses the text for a compare method' do
      expect(@parser.parse(Rhizome::Fixtures::COMPARE_BYTECODE_MRI)).to be == Rhizome::Fixtures::COMPARE_BYTECODE_RHIZOME
    end

    it 'parses the text for a compare method with local variables' do
      expect(@parser.parse(Rhizome::Fixtures::NAMED_COMPARE_BYTECODE_MRI)).to be == Rhizome::Fixtures::NAMED_COMPARE_BYTECODE_RHIZOME
    end

    it 'parses the text for a redundant multiply method' do
      expect(@parser.parse(Rhizome::Fixtures::REDUNDANT_MULTIPLY_BYTECODE_MRI)).to be == Rhizome::Fixtures::REDUNDANT_MULTIPLY_BYTECODE_RHIZOME
    end

    it 'parses the text for an add with side effects method' do
      expect(@parser.parse(Rhizome::Fixtures::ADD_WITH_SIDE_EFFECTS_BYTECODE_MRI)).to be == Rhizome::Fixtures::ADD_WITH_SIDE_EFFECTS_BYTECODE_RHIZOME
    end

  end

end

describe Rhizome::Frontend::RbxParser do

  before :each do
    @parser = Rhizome::Frontend::RbxParser.new
  end

  if Rhizome::Config::RBX

    describe '.text_for' do

      it 'returns the text for the bytecode for an add method' do
        expect(@parser.text_for(Rhizome::Fixtures.method(:add))).to be == Rhizome::Fixtures::ADD_BYTECODE_RBX
      end

      it 'returns the text for the bytecode for a fib method' do
        expect(@parser.text_for(Rhizome::Fixtures.method(:fib))).to be == Rhizome::Fixtures::FIB_BYTECODE_RBX
      end

    end

  end

  describe '.parse' do

    # The bytecode from the Rubinius parser doesn't have trace instructions, so mask_traces removes them and
    # normalises jump and branch offsets to 0.

    it 'parses the text for an add method' do
      expect(Rhizome::Fixtures.mask_traces(@parser.parse(Rhizome::Fixtures::ADD_BYTECODE_RBX)))
          .to be == Rhizome::Fixtures.mask_traces(Rhizome::Fixtures::ADD_BYTECODE_RHIZOME)
    end

    it 'parses the text for a fib method' do
      expect(Rhizome::Fixtures.mask_traces(@parser.parse(Rhizome::Fixtures::FIB_BYTECODE_RBX)))
          .to be == Rhizome::Fixtures.mask_traces(Rhizome::Fixtures::FIB_BYTECODE_RHIZOME)
    end

  end

end

describe Rhizome::Frontend::JRubyParser do

  before :each do
    @parser = Rhizome::Frontend::JRubyParser.new
  end

  if Rhizome::Config::JRUBY

    describe '.text_for' do

      it 'returns the text for the bytecode for an add method' do
        expect(@parser.text_for(Rhizome::Fixtures.method(:add))).to be == Rhizome::Fixtures::ADD_BYTECODE_JRUBY
      end

      it 'returns the text for the bytecode for a fib method' do
        expect(@parser.text_for(Rhizome::Fixtures.method(:fib))).to be == Rhizome::Fixtures::FIB_BYTECODE_JRUBY
      end

    end

  end

  describe '.parse' do

    # We have separate expected bytecode for JRuby as JRuby's format uses registers

    it 'parses the text for an add method' do
      expect(@parser.parse(Rhizome::Fixtures::ADD_BYTECODE_JRUBY)).to be == Rhizome::Fixtures::ADD_BYTECODE_RHIZOME_FROM_JRUBY
    end

    it 'parses the text for a fib method' do
      expect(@parser.parse(Rhizome::Fixtures::FIB_BYTECODE_JRUBY)).to be == Rhizome::Fixtures::FIB_BYTECODE_RHIZOME_FROM_JRUBY
    end

  end

end
