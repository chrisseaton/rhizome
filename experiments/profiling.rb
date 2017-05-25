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

# Illustrates how the interpreter can profile your Ruby program.

require_relative '../lib/rhizomeruby'
require_relative '../spec/rhizomeruby/fixtures'

# We run run the interpreter normally...

def fib(n)
  if n < 2
    n
  else
    fib(n - 1) + fib(n - 2)
  end
end

interpreter = Rhizome::Interpreter.new

100.times do
  interpreter.interpret Rhizome::Fixtures::FIB_BYTECODE_RHIZOME, Rhizome::Fixtures, [10]
end

# Or we can run with a profile...

profile = Rhizome::Profile.new

100.times do
  interpreter.interpret Rhizome::Fixtures::FIB_BYTECODE_RHIZOME, Rhizome::Fixtures, [10], profile
end

# This profile will then be able to give us information about what your
# program did at runtime, giving us more information than we would be
# able to determine statically.

profile.sends.each_value do |profile|
  puts profile
end
