# Copyright (c) 2016-2017 Chris Seaton
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

# Prints a simple graph for an add function.

require_relative '../lib/rhizomeruby'
require_relative '../spec/rhizomeruby/fixtures'

puts 'this experiment would draw graphs if you had Graphviz installed' unless Rhizome::IR::Graphviz.available?

builder = Rhizome::IR::Builder.new
fragment = builder.basic_block_to_fragment(Rhizome::Fixtures::ADD_BYTECODE_RHIZOME)
graph = Rhizome::IR::Graph.from_fragment(fragment)
postbuild = Rhizome::Passes::PostBuild.new
postbuild.run graph

if Rhizome::IR::Graphviz.available?
  graphviz = Rhizome::IR::Graphviz.new(graph)
  graphviz.visualise 'add.pdf'
end
