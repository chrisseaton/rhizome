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

require 'rubyjit/config'
require 'rubyjit/memory'
require 'rubyjit/handles'
require 'rubyjit/interface'
require 'rubyjit/frontend/mri_parser'
require 'rubyjit/frontend/rbx_parser'
require 'rubyjit/frontend/jruby_parser'
require 'rubyjit/interpreter'
require 'rubyjit/profile'
require 'rubyjit/ir/node'
require 'rubyjit/ir/graph'
require 'rubyjit/ir/graphviz'
require 'rubyjit/ir/builder'
require 'rubyjit/ir/core'
require 'rubyjit/passes/post_build'
require 'rubyjit/passes/dead_code'
require 'rubyjit/passes/no_choice_phis'
require 'rubyjit/passes/inline_caching'
require 'rubyjit/passes/inlining'
require 'rubyjit/passes/deoptimise'
require 'rubyjit/passes/runner'
require 'rubyjit/backend/general/add_tagging'
require 'rubyjit/backend/general/expand_tagging'
require 'rubyjit/backend/general/specialise_branches'
require 'rubyjit/backend/general/expand_calls'
require 'rubyjit/backend/amd64/assembler'
require 'rubyjit/scheduler'
require 'rubyjit/registers'
