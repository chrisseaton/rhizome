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

module RubyJIT
  
  # The config module tells us about the processor and Ruby implementation on
  # which we are running.
  
  module Config
    
    # We currently support just one processor architecture - AMD 64, also known
    # as x86_64. We work out your processor architecture by looking at RbConfig.
    
    AMD64 = RbConfig::CONFIG['host_cpu'] == 'x86_64'
    WORD_BITS = 64
    
    # In some cases macOS does things differently to Linux. Again, use RbConfig
    # to work out what operating system we are running on.
    
    MACOS = /darwin/ === RbConfig::CONFIG['host_os']
    
    # We support the MRI, Rubinius and JRuby implementations of Ruby.
    # RUBY_ENGINE tells us which implementation we are running on.
    
    MRI = RUBY_ENGINE == 'ruby'
    RBX = RUBY_ENGINE == 'rbx'
    JRUBY = RUBY_ENGINE == 'jruby'
    
  end
end
