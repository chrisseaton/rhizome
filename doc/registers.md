# RhizomeRuby

## Register allocator

The Rhizome register allocator decides which values to store in which registers,
and which values to store in memory instead. Your processor almost always has
less registers than we would like, so the register allocator normally has to
decide which registers to re-use to be as efficient as possible in its use of
registers.

### Why we need it

Registers are the fastest memory that your processor has. Reading or writing a
register is many times faster than reading or writing memory even when it is
most hot and stored in the highest level cache, and several orders of magnitude
faster than memory which isn't in cache at all.

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

#### The infinite allocator

For some testing purposes we have a baseline register allocator that works as if
we had an infinite number of registers that we can use. It is useful where a
graph needs to be register allocated in order to test or demonstrate some later
phase of the compiler, but you aren't actually going to generate machine code so
you don't care about how many registers a real processor has.

#### The infinite stack allocator

The infinite register allocator is simple, but you can't actually compile code
that wants to use more registers than your processor has. When we want to
actually compile test code, but still want to keep things as simple as possible
we have a register allocator that always uses stack slots. It doesn't attempt to
re-use any stack slots, and never uses any registers.

#### Phi nodes

The phi nodes that we created when building the graph to say that a value was
taken from two possible values based on what branch of the program was taken are
used as information to guide the register allocator. After register allocation,
all inputs to a phi node should have be in the same register, and then the phi
node itself does nothing in the compiled code.

Register allocation algorithms may not be able to satisfy this requirement (for
example if one value goes to two phi nodes and they want the value in different
registers), so register allocation may also insert `move` nodes above phi nodes
to copy a value from one register into another. For the infinite allocator,
these are always needed as every nodes has its own register and values are never
in the registers that phi nodes want.
