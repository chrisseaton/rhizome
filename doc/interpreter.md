# RubyJIT

## Interpreter

The RubyJIT interpreter executes Ruby code expressed in our bytecode format.

We use the interpreter to continue to execute programs when the just-in-time
compiled code is no longer able to continue due to deoptimisation, which is
explained in another document.

### Why we need it

Being able to abandon the just-in-time compiled code and continue in the
interpreter instead allows us to optimise the compiled code more than we could
do otherwise. This is essential for making Ruby run fast.

### How it works

The interpreter is very simple. It maintains an instruction pointer, which is
the index of the next instruction to execute, an array for the stack, and a hash
to store the value of local variables. It runs in a loop, looking at what the
next instruction is, performing its action, and then setting the instruction
pointer to the next instruction.

The one interesting feature of our interpreter is that it allows you to begin
execution of a method at any point, with any state - the state being the current
stack and the value of all local variables. However this isn't complicated to
implement. We make the instruction pointer, stack and local variable map
parameters and give them empty default values for the case when we don't want to
start the interpreter beyond the start.

### More technical details

There aren't many interesting technical things to say about the interpreter!
It's as simple as described and the extra feature of being able to start
execution at any point is as simple as making three variables into parameters.

### Potential projects

* MRI stores caches alongside instructions to speed up `send` instructions in
  its interpreter. Add these caches to our interpreter, so that `send`
  instructions which always see the same class don't need to look up the method
  to call each time.
