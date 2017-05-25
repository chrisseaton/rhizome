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
  module Backend
    module General

      # Assemblers for different platforms can share this label functionality
      # that stores a location for the label, or can defer a location and
      # patch its value back into already assembled code when it is set.
      
      class Label
        
        attr_reader :location
        
        def initialize(assembler)
          @assembler = assembler
          @patch_points = []
        end

        # Does this label have a location in the program yet?
        
        def marked?
          @location != nil
        end

        # Patch this offset in the compiled code when the label does get a
        # location in the future.
        
        def patch_point(source)
          @patch_points.push [@assembler.location, source]
        end

        # Give the label the location at this point in the assembled code.
        
        def mark
          @location = @assembler.location

          @patch_points.each do |patch_location, source|
            @assembler.patch patch_location, location - source
          end
        end
        
      end
      
    end
  end
end
