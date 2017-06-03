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

# Illustrates code generation.

require_relative '../lib/rhizomeruby'
require_relative '../spec/rhizomeruby/fixtures'

raise 'this experiment only works on AMD64' unless Rhizome::Config::AMD64

interpreter = Rhizome::Interpreter.new
profile = Rhizome::Profile.new

100.times do
  interpreter.interpret Rhizome::Fixtures::ADD_BYTECODE_RHIZOME, Rhizome::Fixtures, [14, 2], profile
end

builder = Rhizome::IR::Builder.new
builder.build Rhizome::Fixtures::ADD_BYTECODE_RHIZOME, profile
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
    Rhizome::Backend::General::AddTagging.new,
    Rhizome::Backend::General::ExpandTagging.new,
    Rhizome::Backend::General::SpecialiseBranches.new,
    Rhizome::Backend::General::ExpandCalls.new
)

passes_runner.run graph

scheduler = Rhizome::Scheduler.new
scheduler.schedule graph

register_allocator = Rhizome::RegisterAllocator.new
register_allocator.allocate graph

blocks = scheduler.linearize(graph)

blocks.each_with_index do |block, n|
  puts "block#{n}:" unless n == 0

  block.each do |insn|
    puts "  #{insn.map(&:to_s).join(' ')}"
  end
end

puts

assembler = Rhizome::Backend::AMD64::Assembler.new
handles = Rhizome::Handles.new
interface = Rhizome::Interface.new(handles)

codegen = Rhizome::Backend::AMD64::Codegen.new(assembler, handles, interface)
codegen.generate blocks

memory = Rhizome::Memory.new(assembler.size)
assembler.patch_for_install_location memory.address.to_i
memory.write 0, assembler.bytes
memory.executable = true
native_method = memory.to_proc([:long, :long, :long], :long)

disassembler = Rhizome::Backend::AMD64::Disassembler.new(assembler.bytes, memory.address.to_i, interface.symbols)

while disassembler.more?
  puts disassembler.next
end

puts
puts 'Using the fast path:'
puts
puts '14 + 2 = ' + interface.call_native(native_method, nil, 14, 2).to_s
puts
puts 'Using the slow path:'
puts
puts '14.2 + 2.1 = ' + interface.call_native(native_method, nil, 14.2, 2.1).to_s
