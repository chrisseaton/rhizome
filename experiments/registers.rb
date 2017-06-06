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

require_relative '../lib/rhizomeruby'
require_relative '../spec/rhizomeruby/fixtures'

puts 'this experiment would draw graphs if you had Graphviz installed' unless Rhizome::IR::Graphviz.available?

builder = Rhizome::IR::Builder.new
builder.build Rhizome::Fixtures::FIB_BYTECODE_RHIZOME
graph = builder.graph

postbuild = Rhizome::Passes::PostBuild.new
postbuild.run graph

passes_runner = Rhizome::Passes::Runner.new(
    Rhizome::Passes::DeadCode.new,
    Rhizome::Passes::NoChoicePhis.new
)

passes_runner.run graph

scheduler = Rhizome::Scheduler.new
scheduler.schedule graph

register_allocator = Rhizome::RegisterAllocator.new

register_allocator.sequence_nodes graph

if Rhizome::IR::Graphviz.available?
  viz = Rhizome::IR::Graphviz.new(graph)
  viz.visualise 'sequenced.pdf'
end

live_ranges = register_allocator.live_ranges(graph)
registers = register_allocator.linear_scan(live_ranges)

puts 'Live ranges:'
puts

live_ranges.each do |range|
  puts "#{range.producer.op} #{range.start} -> #{range.finish} in #{registers[range].name}"
end

registers.each do |range, register|
  range.producer.props[:register] = register.name.to_s.downcase.to_sym
end

live_over_calls = register_allocator.live_over_calls(graph, live_ranges, registers)

puts
puts 'Live on calls:'
puts

live_over_calls.each_pair do |call, live|
  puts "#{call.op} @ #{call.props[:register_sequence]} #{live}"
end
