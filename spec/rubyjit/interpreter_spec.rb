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

describe RubyJIT::Interpreter do

  before :each do
    @interpreter = RubyJIT::Interpreter.new
  end

  describe '#interpret' do

    it 'executes an add method' do
      expect(@interpreter.interpret(RubyJIT::Fixtures::ADD_BYTECODE_RUBYJIT, RubyJIT::Fixtures, [14, 2])).to eql 16
    end

    it 'executes a fib method' do
      expect(@interpreter.interpret(RubyJIT::Fixtures::FIB_BYTECODE_RUBYJIT, RubyJIT::Fixtures, [10])).to eql 55
    end

    it 'executes an add method from any instruction' do
      receiver = RubyJIT::Fixtures

      # Each entry is an instruction pointer to start at, a stack and a map of local variables.

      states = [
        [0,   [],       {}            ],
        [1,   [14],     {}            ],
        [2,   [],       {a: 14}       ],
        [3,   [2],      {a: 14}       ],
        [4,   [],       {a: 14, b: 2} ],
        [5,   [],       {a: 14, b: 2} ],
        [6,   [],       {a: 14, b: 2} ],
        [7,   [14],     {a: 14, b: 2} ],
        [8,   [14, 2],  {a: 14, b: 2} ],
        [9,   [16],     {a: 14, b: 2} ],
        [10,  [16],     {a: 14, b: 2} ]
      ]

      states.each do |ip, stack, locals|
        expect(@interpreter.interpret(RubyJIT::Fixtures::ADD_BYTECODE_RUBYJIT, receiver, [14, 2], nil, ip, stack, locals)).to eql 16
      end
    end

    it 'executes a fib method from any instruction' do
      receiver = RubyJIT::Fixtures

      # Each entry is an instruction pointer to start at, a stack and a map of local variables.

      states = [
        [0,   [],                     {}      ], # [:arg,      0       ],
        [1,   [10],                   {}      ], # [:store,    :n      ],
        [2,   [],                     {n: 10} ], # [:trace,    31      ],
        [3,   [],                     {n: 10} ], # [:trace,    32      ],
        [4,   [],                     {n: 10} ], # [:load,     :n      ],
        [5,   [10],                   {n: 10} ], # [:push,     2       ],
        [6,   [10, 2],                {n: 10} ], # [:send,     :<,   1 ],
        [7,   [false],                {n: 10} ], # [:not               ],
        [8,   [true],                 {n: 10} ], # [:branch,   12      ],
        [12,  [],                     {n: 10} ], # [:trace,    35      ],
        [13,  [],                     {n: 10} ], # [:self              ],
        [14,  [receiver],             {n: 10} ], # [:load,     :n      ],
        [15,  [receiver, 10],         {n: 10} ], # [:push,     1       ],
        [16,  [receiver, 10, 1],      {n: 10} ], # [:send,     :-,   1 ],
        [17,  [receiver, 9],          {n: 10} ], # [:send,     :fib, 1 ],
        [18,  [34],                   {n: 10} ], # [:self              ],
        [19,  [34, receiver],         {n: 10} ], # [:load,     :n      ],
        [20,  [34, receiver, 10],     {n: 10} ], # [:push,     2       ],
        [21,  [34, receiver, 10, 2],  {n: 10} ], # [:send,     :-,   1 ],
        [22,  [34, receiver, 8],      {n: 10} ], # [:send,     :fib, 1 ],
        [23,  [34, 21],               {n: 10} ], # [:send,     :+,   1 ],
        [24,  [55],                   {n: 10} ], # [:trace,    37      ],
        [25,  [55],                   {n: 10} ] # [:return            ]
      ]

      states.each do |ip, stack, locals|
        expect(@interpreter.interpret(RubyJIT::Fixtures::FIB_BYTECODE_RUBYJIT, receiver, [10], nil, ip, stack, locals)).to eql 55
      end
    end

  end

end
