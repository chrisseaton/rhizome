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

# Illustrates allocating registers to values.

require_relative '../lib/rubyjit'
require_relative '../spec/rubyjit/fixtures'

puts 'this experiment would draw graphs if you had Graphviz installed' unless RubyJIT::IR::Graphviz.available?

builder = RubyJIT::IR::Builder.new
builder.build RubyJIT::Fixtures::FIB_BYTECODE_RUBYJIT
graph = builder.graph

postbuild = RubyJIT::Passes::PostBuild.new
postbuild.run graph

passes_runner = RubyJIT::Passes::Runner.new(
    RubyJIT::Passes::DeadCode.new,
    RubyJIT::Passes::NoChoicePhis.new
)

passes_runner.run graph

scheduler = RubyJIT::Scheduler.new
scheduler.schedule graph

registers = RubyJIT::RegisterAllocator.new
registers.allocate_infinite graph

if RubyJIT::IR::Graphviz.available?
  viz = RubyJIT::IR::Graphviz.new(graph)
  viz.visualise 'infinite-registers.pdf'
end
