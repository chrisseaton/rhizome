# Copyright (c) 2016 Chris Seaton
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

require 'rhizomeruby'

describe Rhizome::Memory do
  
  describe '.new' do
    
    it 'accepts a size argument' do
      memory = Rhizome::Memory.new(1024)
      expect(memory.size).to eql 1024
      memory.free
    end
    
    it 'raises an RangeError if size < 0' do
      expect { Rhizome::Memory.new(-1) }.to raise_error(RangeError)
    end
  
    it 'allocates read/write, non-execute memory' do
      memory = Rhizome::Memory.new(1024)
      expect(memory.readable?).to be_truthy
      expect(memory.writable?).to be_truthy
      expect(memory.executable?).to be_falsey
      memory.free
    end
  
  end
  
  describe '#size' do
    
    it 'reports the size' do
      memory = Rhizome::Memory.new(1024)
      expect(memory.size).to eql 1024
      memory.free
    end
    
  end
  
  describe '#readable? and #readable=' do
    
    it 'reports and modifies if memory is readable' do
      memory = Rhizome::Memory.new(1024)
      expect(memory.readable?).to be_truthy
      memory.readable = false
      expect(memory.readable?).to be_falsey
      memory.readable = true
      expect(memory.readable?).to be_truthy
      memory.free
    end
    
  end
  
  describe '#writable? and #writable=' do
    
    it 'reports and modifies if memory is writable' do
      memory = Rhizome::Memory.new(1024)
      expect(memory.writable?).to be_truthy
      memory.writable = false
      expect(memory.writable?).to be_falsey
      memory.writable = true
      expect(memory.writable?).to be_truthy
      memory.free
    end
    
  end
  
  describe '#executable? and #executable=' do
    
    it 'reports and modifies if memory is executable' do
      memory = Rhizome::Memory.new(1024)
      expect(memory.executable?).to be_falsey
      memory.executable = true
      expect(memory.executable?).to be_truthy
      memory.executable = false
      expect(memory.executable?).to be_falsey
      memory.free
    end
    
  end
  
  describe '#read' do
    
    it 'raises an RangeError if the offset is less than zero' do
      memory = Rhizome::Memory.new(1024)
      expect { memory.read(-1, 4) }.to raise_error(RangeError)
      memory.free
    end
    
    it 'raises an RangeError if the offset and the length is beyond the size' do
      memory = Rhizome::Memory.new(1024)
      expect { memory.read(1022, 4) }.to raise_error(RangeError)
      memory.free
    end
    
    it 'raises a StandardError if the memory is not readable' do
      memory = Rhizome::Memory.new(1024)
      memory.readable = false
      expect { memory.read(0, 4) }.to raise_error(StandardError)
      memory.free
    end
    
    it 'reads previously written values' do
      memory = Rhizome::Memory.new(1024)
      memory.write 100, [1, 2, 3, 4]
      expect(memory.read(100, 4)).to eql [1, 2, 3, 4]
      memory.free
    end
    
  end
  
  describe '#write' do
    
    it 'raises an RangeError if the offset is less than zero' do
      memory = Rhizome::Memory.new(1024)
      expect { memory.write(-1, [1, 2, 3, 4]) }.to raise_error(RangeError)
      memory.free
    end
    
    it 'raises an RangeError if the offset and the length of bytes is beyond the size' do
      memory = Rhizome::Memory.new(1024)
      expect { memory.write(1022, [1, 2, 3, 4]) }.to raise_error(RangeError)
      memory.free
    end
    
    it 'raises a StandardError if the memory is not writable' do
      memory = Rhizome::Memory.new(1024)
      memory.writable = false
      expect { memory.write(0, [1, 2, 3, 4]) }.to raise_error(StandardError)
      memory.free
    end
    
    it 'writes values that can then be read' do
      memory = Rhizome::Memory.new(1024)
      memory.write 100, [1, 2, 3, 4]
      expect(memory.read(100, 4)).to eql [1, 2, 3, 4]
      memory.free
    end
    
  end
  
  describe '#to_proc' do
    
    it 'raises a StandardError if the memory is not executable' do
      memory = Rhizome::Memory.new(1024)
      expect { memory.to_proc([:long, :long], :long) }.to raise_error(StandardError)
      memory.free
    end
      
    it 'raises a ArgumentError if the number of arguments does not match the number of types' do
      memory = Rhizome::Memory.new(1024)
      memory.executable = true
      expect { memory.to_proc([:long, :long], :long).call(1, 2, 3) }.to raise_error(ArgumentError)
      memory.free
    end
  
    it 'returns a Proc' do
      memory = Rhizome::Memory.new(1024)
      memory.executable = true
      expect(memory.to_proc([:long, :long], :long)).to be_a(Proc)
      memory.free
    end
    
    it 'will execute minimal machine code written to the method' do
      memory = Rhizome::Memory.new(1024)
      
      if Rhizome::Config::AMD64
        machine_code = [
          0xb8, 0x0e, 0x00, 0x00, 0x00,   # mov 14, rax       rax = 14
          0xc3                            # ret               return rax
        ]
      else
        pending 'no machine code sample for this architecture'
      end
      
      memory.write 0, machine_code
      memory.executable = true
      expect(memory.to_proc([], :long).call).to eql 14
      memory.free
    end
    
    it 'will execute machine code with arguments written to the method' do
      memory = Rhizome::Memory.new(1024)
      
      if Rhizome::Config::AMD64
        machine_code = [
          0x48, 0x89, 0xf8,   # mov rdi, rax          rax = args[0]
          0x48, 0x01, 0xf0,   # add rsi, rax          rax += args[1]
          0xc3                # ret                   return rax
        ]
      else
        pending 'no machine code sample for this architecture'
      end
      
      memory.write 0, machine_code
      memory.executable = true
      expect(memory.to_proc([:long, :long], :long).call(14, 2)).to eql 16
      memory.free
    end
  
  end

  describe '.from_proc' do

    it 'produces a native memory address' do
      expect(Rhizome::Memory.from_proc(:long, [:long]) { }.to_i).to be_an(Integer)
    end

  end

end
