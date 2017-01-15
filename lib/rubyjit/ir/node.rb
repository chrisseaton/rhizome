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

module RubyJIT
  module IR

    class Node

      attr_reader :op
      attr_reader :props
      attr_reader :inputs
      attr_reader :outputs

      def initialize(op, props={})
        @op = op
        @props = props
        @inputs = {}
        @outputs = {}
      end

      def output_to(output_name, to, input_name=output_name)
        outputs[output_name] ||= []
        outputs[output_name].push to
        to.inputs[input_name] ||= []
        to.inputs[input_name].push self
      end

      def has_control_input?
        not inputs[:control].nil?
      end

      def has_control_output?
        not outputs[:control].nil?
      end

      def inspect
        "Node<#{object_id}, #{op}, #{props}>"
      end

    end

  end
end
