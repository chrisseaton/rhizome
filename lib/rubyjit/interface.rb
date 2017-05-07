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

module RubyJIT
  
  # Manages calls into native code, and back into Ruby. The extra
  # responsibility over just doing the call is also in marshalling the
  # arguments in and the return value out.
    
  class Interface
    
    attr_reader :call_managed_address
  
    def initialize(handles)
      @handles = handles
      @call_managed_function = create_call_managed_function
      @call_managed_address = @call_managed_function.to_i
    end
    
    # Call a native function (passed in as a proc).
    
    def call_native(function, *args)
      args = *args.map { |a| @handles.to_native(a) }
      ret = function.call(*args)
      @handles.from_native(ret)
    end
    
    # Create an address for calling back into Ruby that you can call from
    # native code.
    
    def create_call_managed_function
      Memory.from_proc(:long, [:long, :long]) do |args_pointer, args_count|
        # Read the receiver, method name, and then the args from the buffer
        buffer = Memory.new((args_count + 2) * Config::WORD_BYTES, args_pointer)
        handles = buffer.read_words(0, args_count + 2)
        
        # Convert argument handles to objects
        receiver, name, *args = handles.map { |h| @handles.from_native(h) }
        
        # Make the call
        ret = receiver.send(name, *args)
        
        # Convert the return object to a handle
        @handles.to_native(ret)
      end
    end
    
  end
  
end
