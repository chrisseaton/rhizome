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

require 'rhizomeruby/config'
require 'rhizomeruby/memory'
require 'rhizomeruby/handles'
require 'rhizomeruby/interface'
require 'rhizomeruby/frontend/mri_parser'
require 'rhizomeruby/frontend/rbx_parser'
require 'rhizomeruby/frontend/jruby_parser'
require 'rhizomeruby/interpreter'
require 'rhizomeruby/profile'
require 'rhizomeruby/ir/node'
require 'rhizomeruby/ir/graph'
require 'rhizomeruby/ir/graphviz'
require 'rhizomeruby/ir/builder'
require 'rhizomeruby/ir/core'
require 'rhizomeruby/passes/post_build'
require 'rhizomeruby/passes/dead_code'
require 'rhizomeruby/passes/no_choice_phis'
require 'rhizomeruby/passes/canonicalise'
require 'rhizomeruby/passes/constant_fold'
require 'rhizomeruby/passes/global_value_numbering'
require 'rhizomeruby/passes/remove_redundant_guards'
require 'rhizomeruby/passes/inline_caching'
require 'rhizomeruby/passes/inlining'
require 'rhizomeruby/passes/insert_safepoints'
require 'rhizomeruby/passes/deoptimise'
require 'rhizomeruby/passes/runner'
require 'rhizomeruby/backend/general/add_tagging'
require 'rhizomeruby/backend/general/expand_tagging'
require 'rhizomeruby/backend/general/specialise_branches'
require 'rhizomeruby/backend/general/expand_calls'
require 'rhizomeruby/backend/general/label'
require 'rhizomeruby/backend/amd64/assembler'
require 'rhizomeruby/backend/amd64/disassembler'
require 'rhizomeruby/backend/amd64/codegen'
require 'rhizomeruby/scheduler'
require 'rhizomeruby/registers'
