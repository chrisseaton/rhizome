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

describe RubyJIT::Handles do

  before :each do
    @handles = RubyJIT::Handles.new(64)
  end

  describe '#to_native' do

    it 'gives an integer for an object' do
      expect(@handles.to_native(Object.new)).to be_an Integer
    end

    it 'gives an integer for a fixnum' do
      expect(@handles.to_native(14)).to be_an Integer
    end

    it 'gives the same integer for the same object' do
      object = Object.new
      expect(@handles.to_native(object)).to eql @handles.to_native(object)
    end

    it 'gives the same integer for the same fixnum' do
      expect(@handles.to_native(14)).to eql @handles.to_native(14)
    end

    it 'tags fixnums by shifting left and adding one' do
      100_000.times do |n|
        expect(@handles.to_native(n)).to eq ((n << 1) + 1)
      end
    end

  end

  describe '#from_native' do

    it 'gives an object from its handle' do
      object = Object.new
      expect(@handles.from_native(@handles.to_native(object))).to eql object
    end

    it 'gives a fixnum from its handle' do
      expect(@handles.from_native(@handles.to_native(14))).to eql 14
    end

    it 'untags fixnums by shifting right' do
      100_000.times do |n|
        expect(@handles.from_native((n << 1) + 1)).to eq n
      end
    end

  end

end
