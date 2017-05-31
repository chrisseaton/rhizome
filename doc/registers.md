# RhizomeRuby

## Register allocator

The Rhizome register allocator decides which values to store in which registers,
and which values to store in memory instead. Your processor almost always has
less registers than we would like, so the register allocator normally has to
decide which registers to re-use to be as efficient as possible in its use of
registers.

### Why we need it

Registers are like local variables inside your processor. They're the fastest
memory that your processor has. Reading or writing a register is many times
faster than reading or writing memory even when it is most hot and stored in the
highest level cache, and several orders of magnitude faster than memory which
isn't in cache at all.

Therefore we want to store intermediate values that we need as we execute a Ruby
method in registers whenever possible. This isn't possible when we run out of
registers, because there are only so many registers available in your processor.
The alternative to using registers when there aren't any more available, is to
store intermediate values in memory, usually on the stack, which as we've said
is much slower than using a register.

When we run out of registers we want to make a good decision about which values
to put into the registers we do have, and which values to store in memory. We
probably don't want to just put values into registers until we run out and then
start using memory, as some of the later values might impact performance more if
for example they're read many times in a loop.

The register allocator solves this problem of deciding which values to put into
which registers, and which values to put in memory instead.

### How it works

The register allocator operates on a graph which has already been scheduled, and
annotates nodes that produce a value with the name of the register or memory
location which this value will be stored in.

The algorithm we use is called *linear scan*.

#### Live-range analysis

The first step of linear scan register allocation is to build a list of *live
ranges*. A live range is the period of time in the execution of a method where a
value has been produced by a node, until all the users of the node have run and
the value is no longer required.

To represent time we give each node a sequential number. We run register
allocation after scheduling, so the nodes are already in an order, and we just
number each node one higher than all of its inputs.

Each node that produces a value creates a live range. The start of the range is
the number of producing node, and the end of the range is the highest number of
all the users.

This gives us a model of the live ranges where we can see which are live at the
same time. It looks a bit like a Gantt chart, except instead of tasks we have
values that need to be live.

Branches complicate the live range analysis. Some values are produced and used
within a branch so they don't make a difference to any other branches. Some
values need to be kept alive across a branch and merge. Some values a produced
before a branch and then need to be kept alive for different lengths of time in
different sides of the branch.

In Rhizome we ignore this problem and just treat values on both sides of a
branch as being live at the same time. In our simple examples this doesn't seem
to cause a problem, but it would be nice to fix it.

#### Linear scan

Given the list of live ranges, we can now allocate registers. We sort the live
ranges into order by their start time, and go through each in turn. We keep
track of a list of available registers, and a list of ranges which are live at
the moment.

For each live range we look at the start time, and go through our list of ranges
that are currently live. If the start time is at or after the end time of any
currently live ranges, we remove the live range from our list of currently live
ranges, and put its register back in the list of available registers. We then
take one of the available registers and allocate it to the live range, add the
live range to the list of currently available live ranges, and continue to look
at the next live range.

#### Spilling

If we go to allocate a register to a live range and there are none left in our
list of available registers, then we say that we are *spilling* the register,
and we will store it in a memory location instead. In Rhizome we haven't
implemented spilling, because we don't need it for our examples and it
introduces extra complexity to both the register allocator and the code
generator, but the logic isn't much different to allocating a register - we just
allocate a new memory location instead.

#### Ranges of self and arguments

One interesting thing to think about is that when a method is called, the
receiver (the value of self) and the first few arguments as passed in registers.
Does this mean that we can't use those registers to store values in? Or does it
mean we need to save the arguments onto the stack when the method starts and
then load them into another register when needed?

In Rhizome we look for live ranges for values produced by a `self` or `arg`
node, extend their live range back to the start of the method even if they only
appear later in the schedule, and allocate them to the register that they value
is in anyway. When the values are finished being used we return their registers
back to the available list as with any other register, so they can then be
re-used by other values.

#### Phi nodes

The phi nodes that we created when building the graph to say that a value was
taken from two possible values based on what branch of the program was taken are
used as information to guide the register allocator. Ideally, after register
allocation all inputs to a phi node would be in the same register, and then the
phi node itself does nothing in the compiled code.

Register allocation algorithms may not be able to satisfy this requirement (for
example if one value goes to two phi nodes and they want the value in different
registers), so after register allocation we may also insert `move` nodes above
phi nodes to copy a value from one register into another.

#### Preserving registers during calls

We said that registers are like the processor's local variables, but registers
aren't saved when a method call is made - the program has to do that itself. The
convention is that the value of some registers need to be saved by the calling
method, known as *caller-saved*, and some need to be saved by the method that
has been called, known as *callee-saved*.

In Rhizome we currently save all *caller-saved* registers when a method starts,
and all *callee-saved* registers before we make a call. We then restore the
values at the end of the method, or after the call. At the moment we don't think
about which caller-saved registers will be overwritten by our method - if we
don't overwrite a register then we don't need to be saving it - and we don't
think about which callee-saved registers we care about saving - if they don't
have a value in them when the call is made then we also don't need to be saving
it.

#### Other things we could be considering

In our current implementation we treat all registers the same, except for using
lower registers first because these encode in less instruction bytes, and
allocating argument values to the registers that they are in when the method
starts. Really we should be thinking more about where values come from and where
they will eventually end up and trying to make some more intelligent decisions.

A phi node places values from alternative branches into the same value. We said
that we may have to add move instructions to copy a value into the register used
by a phi node if it isn't already in it. We could be working backwards, and
using the knowledge that multiple values will go into a phi node to allocate
their ranges to the same register as the phi node.

Most AMD64 arithmetic instructions are in two-address format (address also
meaning registers in this case), where the second of the two input operands is
also the location to send the result. Like with phi nodes, we could be planning
that the value produced by the arithmetic is put into the same register as the
second operand comes in on. Otherwise we need to move the operand into the
destination register before the arithmetic, or the result into it after the
arithmetic.

Some AMD64 instructions need values to be in particular registers. For example
the `shr` and `shl` shift instructions always take the number of bits to shift
by in the `%cl` register (the lowest byte of `%rcx`, and ignoring shift by an
immediate value for this example). We could allocate values which are used by a
shift into this register, so they don't have to be moved. Instead, Rhizome
reserves the `%rcx` register and always has to add a move into it.

Similarly, the integer or pointer result of a method call always goes into the
`%rax` register. We could be working backwards here as well, storing the value
which will be returned into that register.

Satisfying all these simultaneous and potentially conflicting goals can become
very complicated for register allocation.

### More technical details

Linear scan is an interesting development in register allocation algorithms.
Register allocation is traditionally formulated as the abstract
*graph-colouring* problem. Values are represented as nodes in a graph, and edges
are added between values that need to be live at the same time. At attempt is
then made to assign registers, represented as colours, to nodes so that no nodes
sharing an edge have the same colour. This is like colouring a map so that no
two countries next to each other have the same colour.

Finding an optimal solution to a graph colouring problem is an *NP-complete*
problem. This means that although it is easy to verify a solution to the problem
quickly, there appears to be fundamentally no algorithm which can produce a
solution quickly (we mean 'quickly' in a very informal sense meaning quick
enough to be practical even for large problems - slightly more formally we could
say that nobody knows how to produce a solution in time that doesn't grow
exponentially longer or worse for larger problems).

The approach of linear scan is to step back from this formal modelling of the
problem and and to do something much more intuitive, simple and *linear*. The
linear scan algorithm reportedly performs about 12% as well as graph colouring
algorithms, which is good enough for what we want to achieve in Rhizome.

### Potential projects

* Don't treat two sides of a branch as being live at the same time.
* Implement spilling.
* Only preserve callee-saved registers if we will overwrite their values.
* Only preserve caller-saved registers if they have a value at the point of
  making a call.
* Implement a degree of backwards working - trying to put values into the
  registers that they will need to be in at the end, rather than picking
  whatever register is available at the point of them being produced.
* Implement a more traditional graph colouring register allocator.
