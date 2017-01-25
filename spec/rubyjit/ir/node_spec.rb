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

describe RubyJIT::IR::Node do

  describe '.new' do

    it 'accepts an operation name' do
      node = RubyJIT::IR::Node.new(:name)
      expect(node.op).to eql :name
    end

    it 'accepts a hash of properties' do
      node = RubyJIT::IR::Node.new(:name, a: 1)
      expect(node.props[:a]).to eql 1
    end

  end

  describe '#op' do

    it 'returns the operation name' do
      node = RubyJIT::IR::Node.new(:name)
      expect(node.op).to eql :name
    end

  end

  describe '#properts' do

    it 'returns the hash of properties' do
      node = RubyJIT::IR::Node.new(:name, a: 1)
      expect(node.props[:a]).to eql 1
    end

  end

  describe '#output_to' do

    it 'accepts an output value name, an input value name, and another node' do
      a = RubyJIT::IR::Node.new(:a)
      b = RubyJIT::IR::Node.new(:b)
      a.output_to(:value_out, b, :value_in)
    end

    it 'uses the first name if a second name is omitted' do
      a = RubyJIT::IR::Node.new(:a)
      b = RubyJIT::IR::Node.new(:b)
      a.output_to(:name, b)
      expect(b.inputs.input_names).to include(:name)
    end

    it 'adds the value name to the outputs of the first node' do
      a = RubyJIT::IR::Node.new(:a)
      b = RubyJIT::IR::Node.new(:b)
      a.output_to(:value_out, b, :value_in)
      expect(a.outputs.output_names).to include(:value_out)
    end

    it 'adds the value name to the inputs of the second node' do
      a = RubyJIT::IR::Node.new(:a)
      b = RubyJIT::IR::Node.new(:b)
      a.output_to(:value_out, b, :value_in)
      expect(b.inputs.input_names).to include(:value_in)
    end

    it 'adds the second node to the outputs of the first with that name' do
      a = RubyJIT::IR::Node.new(:a)
      b = RubyJIT::IR::Node.new(:b)
      a.output_to(:value_out, b, :value_in)
      expect(a.outputs.with_output_name(:value_out).to_nodes).to include(b)
    end

    it 'adds the first node to the inputs of the second with that name' do
      a = RubyJIT::IR::Node.new(:a)
      b = RubyJIT::IR::Node.new(:b)
      a.output_to(:value_out, b, :value_in)
      expect(b.inputs.with_input_name(:value_in).from_nodes).to include(a)
    end

    it 'builds an array of multiple outputs with the same name' do
      a = RubyJIT::IR::Node.new(:a)
      b = RubyJIT::IR::Node.new(:b)
      c = RubyJIT::IR::Node.new(:c)
      a.output_to(:value_out, b, :value_in)
      a.output_to(:value_out, c, :value_in)
      expect(a.outputs.with_output_name(:value_out).to_nodes).to contain_exactly(b, c)
    end

    it 'builds an array of multiple inputs with the same name' do
      a = RubyJIT::IR::Node.new(:a)
      b = RubyJIT::IR::Node.new(:b)
      c = RubyJIT::IR::Node.new(:c)
      a.output_to(:value_out, c, :value_in)
      b.output_to(:value_out, c, :value_in)
      expect(c.inputs.with_input_name(:value_in).from_nodes).to contain_exactly(a, b)
    end

  end

  describe '#has_control_input?' do

    it 'is true if there is control input' do
      a = RubyJIT::IR::Node.new(:a)
      b = RubyJIT::IR::Node.new(:b)
      a.output_to(:control, b)
      expect(b.has_control_input?).to be_truthy
    end

    it 'is true if there is multiple control input' do
      a = RubyJIT::IR::Node.new(:a)
      b = RubyJIT::IR::Node.new(:b)
      c = RubyJIT::IR::Node.new(:c)
      a.output_to(:control, c)
      b.output_to(:control, c)
      expect(c.has_control_input?).to be_truthy
    end

    it 'is false if there is no control input' do
      a = RubyJIT::IR::Node.new(:a)
      b = RubyJIT::IR::Node.new(:b)
      a.output_to(:value, b)
      expect(b.has_control_input?).to be_falsey
    end

  end

end
