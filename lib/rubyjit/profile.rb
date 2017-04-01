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

require 'set'

module RubyJIT

  # A profile is a place to store information about how a program behaved
  # when it was actually run. Profiling information is gathered and stored
  # into the profile by the interpreter.

  class Profile

    # Profiling information about a send instruction. Stores the kind of the
    # receiver and the arguments.

    SendProfile = Struct.new(:ip, :receiver_kinds, :args_kinds)

    attr_reader :sends

    def initialize
      @sends = {}
    end

    # Profile a send instruction.

    def profile_send(ip, receiver, args)
      @sends[ip] ||= SendProfile.new(ip, Set.new, [])
      profile = @sends[ip]

      profile.receiver_kinds.add profile_kind(receiver)

      args.each_with_index do |arg, n|
        profile.args_kinds[n] ||= Set.new
        profile.args_kinds[n].add profile_kind(arg)
      end
    end

    # Get the kind of an object.

    def profile_kind(object)
      case object
        when Integer
          if object >= -2**62 && object <= 2**62 - 1
            :fixnum
          else
            :bignum
          end
        else
          object.class
      end
    end

  end

end
