# RubyJIT

## Lowering

Lowering takes a graph with higher-level operations, that more directly match
what you write in Ruby, and produces a graph with lower-level operations, that
more directly match what your processor can execute.

### Why we need it

We need to emit machine code instructions for the nodes in our graph. For
high-level operations each node could result in several machine code
instructions. We could visit each graph and emit one or more machine code
instructions, or we could apply passes to the graph and break down nodes into
more nodes that are simpler so we can emit less instructions for each node.

The advantage of doing this is that other optimisations can be applied to the
new simpler nodes. For example if two high-level nodes both need to untag a
tagged `fixnum` value, then they can share that operation between themselves
rather than them both doing it independently and wasting the work.

### How it works

Lowering is performed by a series of graph passes that work like optimisation
passes. They replace nodes in the graph, add and remove edges, and re-arrange
things so that the graph does the same thing but using operations that are
closer to machine code instructions.

### Add tagging

The high level operation for adding two `fixnum` values together is a
`fixnum_add` node. The high level operation is a `int64_add`, which is something
that your processor can perform. Our `fixnum` values are tagged, so before we
can do a native add operation we need to remove the tag, and after the native
add we need to put the tag back. This is implicit with `fixnum_add`, but we want
to make it explicit when we use `int64_add`.

The add tagging pass replaces `fixnum_add` with `int64_add`, and it inserts
`untag_fixnum` and `tag_fixnum` nodes on each value input and output to the
node. We also replace `kind_is?` nodes that look for a `fixnum` with a
`is_tagged_fixnum?` node.

We discuss overflow in a later document, so it isn't handled by the `int64_add`
at this stage.

### Expand tagging

The tagging operations were made explicit by the previous pass, but they still
aren't a low level operation that your processor understands. The expand tagging
pass expands the tag and untag operations into lower level operations that
implement our tagging protocol, as described in the document on native handles.

The `is_tagged_fixnum?` node becomes an `int64_and` with `1` to mask off the
lowest bit, and an `int64_not_zero?` to test if that bit was set.

The `untag_fixnum` node becomes an `int64_shift_right` by `1`.

The `tag_fixnum` node becomes an `int64_shift_left` by `1` and an `int64_add`
with `1`.

### Specialise branches

In our graph at this stage we have simple `branch` nodes that have a condition
value coming into them to say which side of the branch to take. We can implement
this in machine code, but most processors have instructions that do some kind of
test rather than just checking a condition, such as `branch if zero`. If we did
a test, generated a boolean value, and then passed that as the condition into a
branch we would generate code that did two tests - the actual test and then a
test on the boolean value.

The specialise branches pass moves simple tests from the condition edge into a
branch, into a property in that branch. Instead of being a `branch` node with a
condition that tests `is zero`, the node for the test is removed and the branch
node becomes `branch if zero`, which is something we can directly emit a machine
code instruction for.

### Expand calls

Calls which haven't been inlined remain are translated from a high-level `send`
operation, to a low level `call_managed` operation which will use our call
interface to call back into the host interpreter and perform the call there.

The method name becomes a runtime value, stored in a new constant node and
passed in as a value to the `call_managed` node, just as the receiver and
argument nodes are.

### More technical details

The lowering process is often accompanied with a transition in the data
structure used to represent the program. There may be one data structure for a
high-level intermediate representation (an *HIR*) and another separate data
structure that works in a different way for a low-level intermediate
representation (an *LIR*). We don't do this in RubyJIT because we are trying to
keep the graph in one format, with a single set of operations and debugging
visualisations. This lets us run the same optimisation passes on the lowered
graphs as we did on the high-level graphs.

### Potential projects

* TODO
