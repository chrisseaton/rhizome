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

require 'stringio'

require 'rhizomeruby'

describe Rhizome::IR::Graphviz do

  describe '.new' do

    it 'accepts a graph' do
      graph = Rhizome::IR::Graph.new
      Rhizome::IR::Graphviz.new(graph)
    end

    it 'accepts a graph fragment' do
      merge = Rhizome::IR::Node.new(:merge)
      constant = Rhizome::IR::Node.new(:constant, value: 14)
      graph_fragment = Rhizome::IR::Builder::GraphFragment.new({}, [], merge, merge, merge, {}, [constant])
      Rhizome::IR::Graphviz.new(graph_fragment)
    end

  end

  before :each do
    @builder = Rhizome::IR::Builder.new
    basic_blocks = @builder.basic_blocks(Rhizome::Fixtures::FIB_BYTECODE_RHIZOME)
    block = basic_blocks.values[2]
    @fragment = @builder.basic_block_to_fragment(block.insns)
    @graph = Rhizome::IR::Graph.from_fragment(@fragment)
    @viz = Rhizome::IR::Graphviz.new(@graph)
    dot = StringIO.new
    @viz.write dot
    @dot = dot.string
  end

  describe '#out' do

    it 'produces a graph' do
      expect(@dot.lines.first).to eql "digraph {\n"
      expect(@dot.lines.last).to eql "}\n"
    end

    it 'produces a graph node for each IR node' do
      expect(@dot.scan(/\bnode\d+\[label=/).size).to eql @graph.all_nodes.size
    end

  end
  
  # Only run these specs if dot appears to be installed

  if Rhizome::IR::Graphviz.available?

    describe '#visualise' do

      it 'produces a PDF file' do
        file = 'spec.pdf'
        expect(File.exist?(file)).to be_falsey
        begin
          @viz.visualise file
          expect(File.exist?(file)).to be_truthy
        ensure
          File.delete file if File.exist?(file)
        end
      end

    end

  end

end
