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

module Rhizome
  
  # Manages handles to Ruby objects that native code can use.
  
  class Handles
  
    def initialize(word_bits=Rhizome::Config::WORD_BITS)
      @min = -2**word_bits
      @max = 2**word_bits - 1
      @from_native = {} unless Config::MRI
    end
    
    # Get a native handle for an object.
    
    def to_native(object)
      if object.is_a?(Integer)
        handle = (object << 1) + 1
      else
        handle = object.object_id
        raise if handle & 1 == 1
        @from_native[handle] = object unless Config::MRI
      end
      raise if handle < @min || handle > @max
      handle
    end
    
    # Get an object from a native handle.
    
    def from_native(handle)
      if handle & 1 == 1
        handle >> 1
      elsif Config::MRI
        ObjectSpace._id2ref(handle)
      else
        @from_native[handle]
      end
    end
    
  end
  
end
