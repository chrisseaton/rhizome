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

# Illustrates inlining core library methods.

require_relative '../lib/rubyjit'
require_relative '../spec/rubyjit/fixtures'

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
    RubyJIT::Passes::InlineCaching.new
)

passes_runner.run graph

viz = RubyJIT::IR::Graphviz.new(graph)
viz.visualise 'outer.pdf'

viz = RubyJIT::IR::Graphviz.new(RubyJIT::IR::Core.new.fixnum_op(:+, nil))
viz.visualise 'inner.pdf'

inlining_pass = RubyJIT::Passes::Inlining.new
inlining_pass.run graph

viz = RubyJIT::IR::Graphviz.new(graph)
viz.visualise 'inlined.pdf'

postbuild = RubyJIT::Passes::PostBuild.new
postbuild.run graph

viz = RubyJIT::IR::Graphviz.new(graph)
viz.visualise 'post.pdf'
