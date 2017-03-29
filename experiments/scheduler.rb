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

# Illustrates the scheduling process, deciding what order to run your program in.

require_relative '../lib/rubyjit'
require_relative '../spec/rubyjit/fixtures'

builder = RubyJIT::IR::Builder.new
builder.build RubyJIT::Fixtures::FIB_BYTECODE_RUBYJIT
graph = builder.graph

postbuild = RubyJIT::Passes::PostBuild.new
postbuild.run graph

phases_runner = RubyJIT::Passes::Runner.new(
    RubyJIT::Passes::DeadCode.new,
    RubyJIT::Passes::NoChoicePhis.new
)

phases_runner.run graph

scheduler = RubyJIT::Scheduler.new
scheduler.partially_order graph

viz = RubyJIT::IR::Graphviz.new(graph)
viz.visualise 'order.pdf'

scheduler.global_schedule graph

viz = RubyJIT::IR::Graphviz.new(graph)
viz.visualise 'global.pdf'

scheduler.local_schedule graph

viz = RubyJIT::IR::Graphviz.new(graph)
viz.visualise 'local.pdf'

register_allocator = RubyJIT::RegisterAllocator.new
register_allocator.allocate_infinite graph

blocks = scheduler.linearize(graph)

blocks.each_with_index do |block, n|
  puts "block#{n}:" unless n == 0

  block.each do |insn|
    puts "  #{insn.map(&:to_s).join(' ')}"
  end
end
