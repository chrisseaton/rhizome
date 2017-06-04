# RhizomeRuby

## Assembler

The Rhizome assembler takes the names of assembly code instructions, and their
arguments, and converts them to the binary machine code which your processor can
directly run.

The assembler is an object that has a method on it for each assembly code
instruction. Assembly registers are available as Ruby constants, and registers
support arithmetic to use a register as the base of a computed address. This
makes the Rhizome assembler work a bit like a DSL for writing assembly code in
Ruby.

For example this code assembles a machine code function to add two integers.

```ruby
assembler.push RBP
assembler.mov  RSP, RBP
assembler.mov  RDI, RBP - 0x8
assembler.mov  RSI, RBP - 0x10
assembler.mov  RBP - 0x8, RAX
assembler.mov  RBP - 0x10, RCX
assembler.add  RCX, RAX
assembler.pop  RBP
assembler.ret

assembler.bytes # -> 101010101001000100010011110010101001000100010010111...
```

Rhizome only has an assembler for the AM64 (also know as x86-64, or x64)
instruction set architecture, supported by most laptops and servers.

We'll just take a couple of paragraphs here to explain AMD64 assembly.

Each line is an instruction, with the name of the instruction coming first.
Instructions are followed by operands, which are like arguments if the
instruction were viewed like a function call. We're using what is called the
AT&T convention, used in HotSpot and Unix, where the source comes first, and
then the destination. Operands are usually registers, which are like local
variables inside your processor. If you write `+` or `-` a number after a
register it means to read or write memory at the address stored in the register
plus or minus the number as an offset. That sounds very specific, but it turns
out to be pattern that you want a lot.

An instruction like `ret` has no operand, and returns from the function, like
`return` does in Ruby.

An instruction like `push` or `pop` has just one operand and either reads from
it, in the case of `push` which pushes the value onto the stack from a register,
or writes to it in the case of `pop` which pops a value off the stack into the
register.

An instruction like `mov` or `add` copies a value from the source to the
destination, and in the case of `add` adds it to the value that is already in
the destination.

The registers that we are using here are `RBP` and `RSP`, which store the
location of this functions local variables on the stack, and the current top of
the stack, respectively. We also use `RDI` which is usually the first argument
to a function, and `RSI`, which is usually the second. `RCX` is just a general
purpose register we're using here to store a temporary value, and `RAX` the same
except it is also where the return value for a function goes.

This code stores the `RBP` from the calling function on the stack, and then
stores the current top of the stack, `RSP`, which will be the start of where we
store our local variables, into `RBP`. It then stores the two arguments onto the
stack as local variables. It stores into the stack by referencing the function's
stack space, which remember we just put into `RBP`, minus an offset that is
unique for each local variable.

The code then loads them back out (which is redundant we know, but we're just
illustrating basic instructions) into `RAX` and `RCX` which are two general
purpose registers. We then add them together and store the result back into
`RAX`, where we leave it for the calling function to read the return value.

We'll explain other details of AMD64 assembly where relevant, but it isn't
essential to know much more to understand how Rhizome works.

### Why we need it

The assembler adds a level of abstraction, so that the code choosing which
machine code instructions to use to implement your Ruby code does not have to
worry about how they represented as binary machine code for the processor to
actually read and execute.

### How it works

Registers are Ruby objects stored in constants, with `-` and `+` operators that
wrap them into an address object referencing both the register and the value
that was added or subtracted.

The assembler object is just a wrapper around an array of bytes, with a method
for each instruction which pushes more bytes onto the end of the array, based on
the rules for encoding AMD64 machine code.

#### Labels and jumps

The only complexity in the interface to the assembler (so aside from the actual
encoding, described below) is labels and jumps.

Assembly code doesn't have structured control-flow, such as `if` statements and
`while` loops. Instead it has labels and instructions similar to `goto`
statements as languages such as C have.

For example, an infinite loop has a label, a loop body, and then a jump back to
the label. The label is a Ruby object that the assemler gives you.

```ruby
head = assembler.label
# Loop body here
assembler.jmp head
```

This works well for backward jumps, because when we emit the `jmp` instruction
we already know where the `head` label was. If we want to jump forwards, to jump
over conditional code, we won't know the location of the label when we want to
emit the jump.

When we want to do this we emit a `jmp` instruction (or similar such as `jne`,
meaning jump-if-not-equal in the previous `cmp` comparison), but don't pass a
label object. Instead the assembler will pass a new label back to us, which we
can then pass to the `label` method later.

```ruby
assembler.cmp rX, rY
else_part = assembler.jne
# then part here
finished = assembler.jmp
assembler.label else_part
# else part here
assembler.label finished
```

Internally, the assembler emits a jump to `0` when you jump to a label that
hasn't been defined yet, and records all the places that it has done so. When
you do define the label later on, it goes back to the record of places where the
jump was used before it was defined and patches the actual relative address in.

#### Patching for installed location

Jumps to labels can be patched as the code is generated because a relative
address is used in jump instructions and we know how far apart the jump and
label are. However, `call` instructions use relative addressing but to a target
that is already installed and so already has a fixed address - such as code from
another method or a runtime routine. We can't work out the relative address
until the code we are generating is installed.

Perhaps we could allocate the memory for our code before we started generating
it, so we already know where the code would be installed, but we don't know how
much space our code will take until we have generated it.

Instead, what we do is emit a call to relative address `0`, as with jumps to a
label that is not yet defined. The assembler records that there is a pending
relative address at that location. We then provide a method in the assembler to
patch the code when the installed address is known - so after the memory has
been allocated and before the machine code bytes are copied into it.

#### References

In some cases you may want to reference Ruby objects from compiled code that you
emit from the assembler. The Ruby GC does not understand our compiled code, so
if the only place that the objects are referenced from is the compiled code the
GC may collect them. To prevent this, the assembler maintains a conventional
Ruby `Array` of objects that were referenced from the compiled code. As long as
you reference the assembler or this array of references, the objects will be
kept alive.

### More technical details

The rules for encoding assembly instructions to machine code bytes in AMD64 are
extremely complicated. They're documented along with other details for
Intel-compatible processors in a [2,234 page manual](intel).

[intel]: https://software.intel.com/en-us/articles/intel-sdm

The design of ADM64 has a long legacy and there are also considerations such as
using as few bytes as possible for common cases (the encoding is effectively
compressed) and allowing the processor to decode efficiently. An instruction
which you may think would be very simple, such as `mov` actually has 34
different ways of being encoded for different types of operands. There is a
specified way to encode all of these, but it is far from simple.

In Rhizome we have implemented a small subset of AMD64 instruction encoding to
keep the code simple, but this means that the number of instructions available
to use is limited. For example, it is normally possible to add a value in a
register to a value loaded from memory and store the result back to memory in
one instruction, but we haven't implemented the encoding for this so we would
load in one instruction, do an add that only uses registers because that's
easier to encode, and then store in another instruction.

This means we generate less efficient code, but for the examples we have it
isn't very important. Some machines with simpler architectures, such as RISC
machines or load-store architectures, are always programmed like this.

### Potential projects

* Implement encoding for a wider range of instructions and improve our code
  generation to use them.
