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

require_relative '../lib/rubyjit'
require_relative '../spec/rubyjit/fixtures'

raise 'this experiment only works on AMD64' unless RubyJIT::Config::AMD64

interpreter = RubyJIT::Interpreter.new
profile = RubyJIT::Profile.new

100.times do
  interpreter.interpret RubyJIT::Fixtures::ADD_BYTECODE_RUBYJIT, RubyJIT::Fixtures, [14, 2], profile
end

builder = RubyJIT::IR::Builder.new
builder.build RubyJIT::Fixtures::ADD_BYTECODE_RUBYJIT, profile
graph = builder.graph

passes_runner = RubyJIT::Passes::Runner.new(
    RubyJIT::Passes::PostBuild.new,
    RubyJIT::Passes::DeadCode.new,
    RubyJIT::Passes::NoChoicePhis.new,
    RubyJIT::Passes::InlineCaching.new,
    RubyJIT::Passes::Inlining.new,
    RubyJIT::Passes::InsertSafepoints.new
)

passes_runner.run graph

passes_runner = RubyJIT::Passes::Runner.new(
    RubyJIT::Backend::General::AddTagging.new,
    RubyJIT::Backend::General::ExpandTagging.new,
    RubyJIT::Backend::General::SpecialiseBranches.new,
    RubyJIT::Backend::General::ExpandCalls.new
)

passes_runner.run graph

scheduler = RubyJIT::Scheduler.new
scheduler.schedule graph

register_allocator = RubyJIT::RegisterAllocator.new
register_allocator.allocate_infinite_stack graph

blocks = scheduler.linearize(graph)

blocks.each_with_index do |block, n|
  puts "block#{n}:" unless n == 0

  block.each do |insn|
    puts "  #{insn.map(&:to_s).join(' ')}"
  end
end

puts

assembler = RubyJIT::Backend::AMD64::Assembler.new
handles = RubyJIT::Handles.new
interface = RubyJIT::Interface.new(handles)

codegen = RubyJIT::Backend::AMD64::Codegen.new(assembler, handles, interface)
codegen.generate blocks

machine_code = assembler.bytes

disassembler = RubyJIT::Backend::AMD64::Disassembler.new(machine_code)

while disassembler.more?
  puts disassembler.next
end

memory = RubyJIT::Memory.new(machine_code.size)
memory.write 0, machine_code
memory.executable = true
native_method = memory.to_proc([:long, :long, :long], :long)

puts
puts 'Using the fast path:'
puts
puts '14 + 2 = ' + interface.call_native(native_method, nil, 14, 2).to_s
puts
puts 'Using the slow path:'
puts
puts '14.2 + 2.1 = ' + interface.call_native(native_method, nil, 14.2, 2.1).to_s
