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

# The mechanism that we use to call native functions and access native memory
# varies by the implementation of Ruby.

if RubyJIT::Config::RBX
  # Rubinius' built-in FFI.
  require 'rubinius/ffi'
elsif RubyJIT::Config::JRUBY
  # JRuby's built-in FFI.
  require 'ffi'
else
  # The Fiddle standard library.
  require 'fiddle'
  require 'fiddle/import'
end

module RubyJIT
  
  # The memory system allocates, allows us to set permission on, reads and
  # writes, and executes native memory.
  
  class Memory
    
    # We use six constants and three functions that are common on POSIX systems.
    # I actually think that MAP_ANON may not be part of any POSIX standard, but
    # in practice it is widely available.
    
    module POSIX
      
      PROT_READ     = 0x1
      PROT_WRITE    = 0x2
      PROT_EXEC     = 0x4
      
      if Config::MACOS
        MAP_ANON    = 0x1000
      else
        MAP_ANON    = 0x20
      end
      
      MAP_PRIVATE   = 0x2
      MAP_FAILED    = 0xffffffffffffffff
      
      # The FFI and Fiddle have two different DSLs for declaring that you're
      # using a native function. In each case we're saying which functions
      # we want and their type signature, using C type nomenclature. FFI uses
      # more of a conventional Ruby DSL, while Fiddle lets you write code
      # similar to C but in a String.
      
      if Config::RBX || Config::JRUBY
        extend FFI::Library
        ffi_lib FFI::Library::LIBC
        attach_function :mmap, [:pointer, :size_t, :int, :int, :int, :off_t], :pointer
        attach_function :mprotect, [:pointer, :size_t, :int], :int
        attach_function :munmap, [:pointer, :size_t], :int
      else
        extend Fiddle::Importer
        dlload Fiddle::Handle::DEFAULT
        extern 'void* mmap(void*, size_t, int, int, int, size_t)'
        extern 'int mprotect(void*, size_t, int)'
        extern 'int munmap(void*, size_t)'
      end
      
    end
    
    def initialize(size)
      raise RangeError if size < 0
      
      @size = size
      @readable = true
      @writable = true
      @executable = false
      
      if Config::RBX || Config::JRUBY
        null = FFI::Pointer.new(0)
      else
        null = 0
      end
      
      # Here is the key call to mmap. The first parameter is the null pointer
      # and means that we don't care where this memory is located within the
      # address space. Then we pass the size - how many bytes we need. We then
      # say that the memory should be initially read/write, then say that it's
      # 'anonymous' which means not backed by any actual file on disk, and then
      # we say that it should be private to just this process.
      
      @address = POSIX::mmap(null, size, POSIX::PROT_READ | POSIX::PROT_WRITE, POSIX::MAP_ANON | POSIX::MAP_PRIVATE, 0, 0)
      
      # Check for error information in the return value.
      
      if Config::RBX || Config::JRUBY
        code = @address.address
      else
        code = @address.to_i
      end
      
      raise StadardError if code == POSIX::MAP_FAILED
      
      # We will normally free the memory manually, as we want it to happen as
      # soon as possible and not wait for the GC to free this object, and then
      # free the native memory only when that has happened. However if things
      # go wrong we do ask the finalizer to free the native memory as a last
      # resort if it hasn't been done properly already.
      
      ObjectSpace.define_finalizer self, proc {
        free if @address
      }
    end
    
    attr_reader :size
    
    def readable?
      @readable
    end
    
    def readable=(readable)
      @readable = readable
      protect
    end
    
    def writable?
      @writable
    end
    
    def writable=(writable)
      @writable = writable
      protect
    end
    
    def executable?
      @executable
    end
    
    def executable=(executable)
      @executable = executable
      protect
    end
    
    def write(offset, bytes)
      raise 'memory not writable' unless writable?
      raise RangeError if offset < 0 || offset + bytes.size > size
      
      # The various FFIs want binary data as a compact String but in the rest
      # of RubyJIT we deal with it as an array of Integers for higher level
      # simplicity. This call to pack converts from an array of bytes to a
      # string.
      
      string = bytes.pack('C*')
      
      if Config::RBX || Config::JRUBY
        (@address + offset).write_string string
      else
        @address[offset, bytes.length] = string
      end
    end
    
    def read(offset, length)
      raise 'memory not readable' unless readable?
      raise RangeError if offset < 0 || offset + length > size
      
      if Config::RBX || Config::JRUBY
        string = (@address + offset).read_string(length)
      else
        string = @address[offset, length]
      end
      
      string.bytes
    end
    
    # The to_proc method makes the machine code instructions contained in this
    # block of memory available to be called and executed by the processor
    # as if it was a Ruby Proc object.
    
    def to_proc(arg_types, ret_type)
      raise 'memory not executable' unless executable?
      
      # The various FFI mechanisms already provide the basic tool we need for
      # taking a native memory address and allowing it to be called as a
      # Ruby method, but they use different names for the types. We use the
      # FFI gem's names, as used in Rubinius and JRuby, and translate for
      # MRI and Fiddle.
      
      if Config::RBX || Config::JRUBY
        func = FFI::Function.new(ret_type, arg_types, @address, :blocking => true)
      else
        types_map = {
          long: Fiddle::TYPE_LONG
        }
        
        func = Fiddle::Function.new(@address, arg_types.map(&types_map), types_map[ret_type])
      end
      
      proc { |*args|
        raise ArgumentError if args.size != arg_types.size
        
        # This is the point where we start executing native machine code
        # instructions that we've compiled ourselves.
        
        func.call(*args)
      }
    end
    
    def free
      raise 'already freed' unless @address
      POSIX::munmap(@address, @size)
      @address = nil
    end
    
    private
    
    def protect
      flags = 0
      flags |= POSIX::PROT_READ if readable?
      flags |= POSIX::PROT_WRITE if writable?
      flags |= POSIX::PROT_EXEC if executable?
      result = POSIX::mprotect(@address, @size, flags)
      raise 'could not change memory permissions' unless result
    end
    
  end
  
end
