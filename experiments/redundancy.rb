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

# Demonstrates various passes that remove redundancy.

require_relative '../lib/rhizomeruby'
require_relative '../spec/rhizomeruby/fixtures'

puts 'this experiment would draw graphs if you had Graphviz installed' unless Rhizome::IR::Graphviz.available?

interpreter = Rhizome::Interpreter.new
profile = Rhizome::Profile.new

100.times do
  interpreter.interpret Rhizome::Fixtures::REDUNDANT_MULTIPLY_BYTECODE_RHIZOME, Rhizome::Fixtures, [14], profile
end

builder = Rhizome::IR::Builder.new
builder.build Rhizome::Fixtures::REDUNDANT_MULTIPLY_BYTECODE_RHIZOME, profile
graph = builder.graph

passes_runner = Rhizome::Passes::Runner.new(
    Rhizome::Passes::PostBuild.new,
    Rhizome::Passes::DeadCode.new,
    Rhizome::Passes::NoChoicePhis.new,
    Rhizome::Passes::InlineCaching.new,
    Rhizome::Passes::Inlining.new,
    Rhizome::Passes::InsertSafepoints.new
)

passes_runner.run graph

passes_runner = Rhizome::Passes::Runner.new(
    Rhizome::Passes::Deoptimise.new,
    Rhizome::Passes::DeadCode.new,
    Rhizome::Passes::NoChoicePhis.new
)

passes_runner.run graph

passes_runner = Rhizome::Passes::Runner.new(
    Rhizome::Backend::General::AddTagging.new
)

passes_runner.run graph

if Rhizome::IR::Graphviz.available?
  viz = Rhizome::IR::Graphviz.new(graph)
  viz.visualise 'high-before.pdf'
end

passes_runner = Rhizome::Passes::Runner.new(
    Rhizome::Passes::ConstantFold.new,
    Rhizome::Passes::RemoveRedundantGuards.new,
    Rhizome::Passes::DeadCode.new
)

passes_runner.run graph

if Rhizome::IR::Graphviz.available?
  viz = Rhizome::IR::Graphviz.new(graph)
  viz.visualise 'high-after.pdf'
end

passes_runner = Rhizome::Passes::Runner.new(
    Rhizome::Backend::General::ExpandTagging.new,
    Rhizome::Backend::General::SpecialiseBranches.new,
    Rhizome::Backend::General::ExpandCalls.new
)

passes_runner.run graph

if Rhizome::IR::Graphviz.available?
  viz = Rhizome::IR::Graphviz.new(graph)
  viz.visualise 'low-before.pdf'
end

passes_runner = Rhizome::Passes::Runner.new(
    Rhizome::Passes::GlobalValueNumbering.new
)

passes_runner.run graph

if Rhizome::IR::Graphviz.available?
  viz = Rhizome::IR::Graphviz.new(graph)
  viz.visualise 'low-after.pdf'
end

scheduler = Rhizome::Scheduler.new
scheduler.schedule graph

register_allocator = Rhizome::RegisterAllocator.new
register_allocator.allocate_infinite_stack graph

blocks = scheduler.linearize(graph)

blocks.each_with_index do |block, n|
  puts "block#{n}:" unless n == 0

  block.each do |insn|
    puts "  #{insn.map(&:to_s).join(' ')}"
  end
end

handles = Rhizome::Handles.new
interface = Rhizome::Interface.new(handles)
assembler = Rhizome::Backend::AMD64::Assembler.new(handles)

codegen = Rhizome::Backend::AMD64::Codegen.new(assembler, handles, interface)
codegen.generate blocks

machine_code = assembler.bytes

disassembler = Rhizome::Backend::AMD64::Disassembler.new(machine_code)

while disassembler.more?
  puts disassembler.next
end

memory = Rhizome::Memory.new(machine_code.size)
memory.write 0, machine_code
memory.executable = true
native_method = memory.to_proc([:long, :long], :long)

puts "Installed code to 0x#{memory.address.to_i.to_s(16)}"
puts
puts 'redundant_multiply(14) = ' + interface.call_native(native_method, Rhizome::Fixtures, 14).to_s

# We turned off frame states for simplicity - don't try to use the slow path
