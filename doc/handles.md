# RubyJIT

## Native handles and tagging

RubyJIT needs to somehow refer to Ruby objects in native code, using only the
primitives that the processor understands. We can't use raw pointers to objects
from the host virtual machine, as we cannot easily get access to these, so
instead we use handles - unique, word-sized integers - that map to Ruby objects.

For some objects, such as small integers, we want access to be very fast, so we
encode these objects as special handles that can be encoded and decoded directly
in machine code without talking to the host virtual machine. This is called
'tagging'.

### Why we need it

When we call a native function that RubyJIT has compiled and pass it a Ruby
object as an argument, what do we actually pass into the native code?

We can't pass a pointer to the host virtual machine's representation of the Ruby
object, because this is not easily accessible using the Fiddle and FFI
interfaces that we use for calling native code, and in some implementations with
copying garbage collectors, there may not be a single stable pointer to the
object in the first place.

We need something that native code can work with, so ultimately an integer,
probably the same size as a pointer so that we can store it like a pointer. We
need to be able to create it for a Ruby object, and we need to get back the Ruby
object when we go back into the host virtual machine.

### How it works

We will create *native handles* to refer to Ruby objects in the host virtual
machine. These are just integer values that we can map to and from objects, with
some corner cases for small integer objects for performance.

#### Handles

We need a unique integer to represent each object. Ruby already provides this in
the `object_id` method on all objects. Ruby also provides a way to reverse this
to get the object from its ID, in the `ObjectSpace._id2ref` method. What's more,
on some implementations this is even actually the real pointer to the object
that we said we couldn't get hold of! But this property, and the method
`_id2ref` is not available in the default configuration of JRuby, so we won't
use it.

Instead we will use `object_id` to get natives handles for objects, but maintain
our own map of handles back to objects, which is more portable. This map is
maintained in the `Handles` class. Entries in the map are removed using finalisers which are run when the garbage collector deletes the object.

#### Tagged fixnums

We want to do something special for small integers - the `fixnum` values that
were a separate class in Ruby prior to version 2.4, but are now still treated
specially even if this isn't visible to the programmer.

Small integers are very common in programs, and optimising them well has
knock-on effects for optimising higher-level operations like indexing arrays and
strings. On MRI if you ask for the `object_id` for a small integer, you'll get a
value that doesn't look like a real native pointer. For example, the `object_id`
for `1` is `3`, and for `100` is `201`. This is because these objects aren't
like others - the pointer, or the `object_id`, is actually the integer value as
well.

MRI creates an `object_id` for a `fixnum` by shifting the bits in it left by
one, and then adding one. `1` is shifted left be one, to give `2`, and then one
is added to give `3`. `100` is shifted left by one, to give `200`, and then one
is added to give `201`. It does this so that the `object_id` for a `fixnum`
always has the lowest bit set, no matter what the value is. Native machine
pointers, and `object_id`, are never going to an odd number of bytes for
something like a Ruby object, so they will never have the lowest bit set, so
there is no conflict.

You can take the `object_id` for a `fixnum` and get the value back by shifting
right by one. You don't need to subtract the one, as the one is shifted off the
right-hand side of the value.

This is really important to use because RubyJIT can emit machine code to do
these operations directly, without having to talk to the host virtual machine.
We can detect if a handle is a `fixnum` by looking at the bottom bit, and we can
convert a handle to an integer value if it is a `fixnum` by shifting right by
one. Both those operations are just one machine instruction on most
architectures.

#### Interaction with optimisations and deoptimisation

When we inline core methods such as `fixnum#+`, we add nodes to the graph that
work directly on `fixnum` values, such as `fixnum_add`. These work on tagged
values. When we run the general lower optimisation phase we replace these with
nodes that work on native integer values, where the tagging has been removed,
such as `int32_add`. We add nodes before and after this operation to remove the
tagging from the input, and add it back again to the output, `fixnum_untag` and
`fixnum_tag`.

After the general lower optimisation pass, these nodes appear like any other in
the graph, and have other optimisations applied to them. A `fixnum_tag` followed
by a `fixnum_untag` cancel out (we say they *annihilate* each other), and
through global value numbering multiple redundant `fixnum_tag` or `fixnum_untag`
operations can be combined into one.

If there is a simple fast path through a method that only deals with small
integers, the tagging operations should be optimised away to only happen on
method entry and method return, and they're only single instruction operations
only.

JRuby doesn't use tagged pointers. Instead it *boxes* small integers into fields
in full objects and passes them around as references to the objects. The
optimisation passes in JRuby attempt to do the same cancelling out of tagging
followed by untagging as we do, and the JVM's compilers then do the same again
if some opportunities were missed.

Rubinius does use tagged pointers and uses a similar approach to us. Like us,
they lower to expose the tagging operations and let LLVM optimisation passes
remove the redundancy.

### More technical details

All this discussion boils down into not much more code than `object.object_id`
and `@from_native[handle]` in the `Handles` class, and then logic in the general
lower phase to tag and untag `fixnum` objects, but it's one of those things that
really shows the power of an optimising compiler when you see how it interacts
with other conventional optimations and deoptimisation to keep the fast path of
a method using native integers where possible.

Most virtual machines probably use tagging, and the JVM and so JRuby stands out
for using boxing of small integers. Boxing isn't a problem when the compiler's
optimisations can see where the box is created and used, because it can remove
the box, but if boxes hang around they need to be allocated on the heap and
garbage collected, which all potentially causes multiple pauses and stalls. And
in our case these native handles are about passing things from the host virtual
machine to native code, which is a boundary that by definition is not visible to
optimisations.

However, the JVM does do something that is interesting and related with its
pointers. It stores them in a compressed format if the heap is small enough -
chopping off the upper bits and shifting down over the lower bits to squeeze the
pointer into half the normal size. In a language like Java where you have lots
of objects, this can save a lot of space. You then need to add operations to
uncompress and re-compress pointers when they need to be used. The sophisticated
instruction sets of some processors makes it easier and quicker to do this than
you would expect, by kind of accessing the pointer as an array and using a
pretend index and array element size to do the compression operation.

We've been talking a special case for integers here, but the same technique can be applied for small floating-point values as well. MRI does this, calling them `flonums`.

### Potential projects

* Implemented compressed ordinary object pointers.
* Implement tagged pointers for floating-point values.
