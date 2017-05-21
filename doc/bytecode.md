# RubyJIT

## Bytecode format

RubyJIT's bytecode format is the format in which we represent Ruby methods when
they are first fed into RubyJIT. We define our own bytecode format because the
formats used by the different Ruby implementations vary, and we convert from
their formats to ours. Along with the use of the foreign function interface in
the memory system, this is one of only a couple of places where RubyJIT has to
do things different on different implementations of Ruby.

The RubyJIT interpreter also works using our own bytecode format, so that it can
be the same on all Ruby implementations.

Our bytecode format for RubyJIT is stack-based and tries to use a small number
of instructions that are each very simple.

This document is just about the design of the bytecode format. The parser and
interpreter for the bytecode format are described in other documents.

### Why we need it

Our bytecode format is the input data structure for representing Ruby code to
our compiler. It abstracts the differences between the internal formats used by
the different implementations of Ruby, it allows our compiler to only deal with a
single format, and it allows us to isolate the parts of RubyJIT that depend on
which Ruby implementation you are running.

Our bytecode format is also used as the working data structure for our Ruby
interpreter. The interpreter, and why we need one to build a just-in-time
compiler, is explained in another document.

### How it works

Bytecode is a way of representing programs as a data structure. It is similar to
the machine code instructions that your real processor executes, but the name
'bytecode' usually implies that it is only for use in software such as a virtual
machine, and that it is much higher level than a processor uses. The name
bytecode also implies that it's a serialisation format for storing the code
(serialised as a sequence of bytes) but that isn't what we are using it for in
RubyJIT.

Bytecode is generally a linear sequence of instructions, executed one after the
other, each instruction performing usually some small and simple task. An
instruction can cause the program to branch off to a different instruction,
which is how we get control flow.

There are many different ways to design a bytecode format.

#### Register or stack

One decision to make when designing a bytecode format is between a register
format and a stack format. A register-based bytecode stores temporary data in
variables called registers, which are similar to the machine registers in your
real processor. A stack-based bytecode stores temporary data in a stack data
structure. Values can only be pushed on and popped off. That sounds restrictive
but it can represent as many programs as a register format.

An example of a stack-based bytecode format would be `push a; push b; add`. The
variables `a` and `b` are pushed onto the stack in turn and then the `add`
instruction implicitly pops off two values and pushes the result. We don't have
to say which values as it always uses whatever the top two values on the stack
are. An example of a register-based bytecode format would be `c = add a b`. This
is more compact, but the instruction has been made more complex as it now needs
names to read from and write to.

MRI uses a stack format, maybe because it was an easy transition from their
earlier implementation technique, an abstract syntax tree interpreter, which
implicitly uses a stack. Rubninius uses a stack format perhaps to be similar to
MRI. JRuby uses a register format, because so does much of the literature on
traditional compiler optimisations, and that's what they wanted to enable.

For the RubyJIT bytecode format we've used a stack format, because we think it's
simpler in general. There's not much of a technical argument in this - it's
mostly opinion.

Note that we have a potential problem here. JRuby uses a register format, but
RubyJIT a stack format. Thankfully it's possible to convert from one to the
other, as described in the parser document.

#### Normalised or denormalised

Another decision to make when designing a bytecode format is whether to have
lots of instructions that do a lot of things, and then so programs that need few
of them, or fewer instructions that each do less, and then so each instruction
can be simpler to understand. We can talk about this as being normalised or
denormalised.

MRI uses a more denormalised format with more instructions that each do more.
Rubinius and JRuby use a more normalised format with fewer instructions that
each do less.

An example of a very normalised instruction is RubyJIT's `send` instruction. It
is the only way to call methods in the RubyJIT bytecode format. An example of a
very denormalised instruction is MRI's `opt_plus`. It calls methods, but only
those called `+`, and only if it doesn't take a block (RubyJIT doesn't support
blocks however). This design allows MRI's interpreter to be faster, but it does
also mean a more complex bytecode format.

For the RubyJIT bytecode format we have minimised the number of instructions and
made each do as little as possible for a more normalised format. This way each
is easy to understand and implement, but there are more needed in a program. For
example, all the other bytecode formats used in Ruby implementations have both a
`branch` and `branchunless` instruction (corresponding to `if` and `unless`). In
RubyJIT there is just a single `branch` instruction. If you want `branchunless`
you'd use `not` and then `branch`.

#### The instruction set

These are the instructions in the RubyJIT bytecode format:

* `trace line` marks a line for `set_trace_func`
* `self` pushes `self` onto the stack
* `arg n` pushes the nth argument onto the stack
* `load name` loads a local variable onto the stack
* `store name` pops a value off the stack into a local variable
* `push value` pushes a value such as a number onto the stack
* `send name argc` pops `argc` number of parameters off the stack, and then a value, and calls a method on the value with the parameters
* `not` negates the value on the top of the stack
* `jump index` jumps to the instruction at index
* `branch index` pops a value off the stack and branches to the instruction at index if it is true
* `return` pops a value off the stack and returns it

#### Example

Here is a simple add function implemented in the different bytecode formats.

```ruby
def add(a, b)
  a + b
end
```

The MRI format uses a special instruction for a call to `+`.

```
local table (size: 2, argc: 2 [opts: 0, rest: -1, post: 0, block: -1, kw: -1@-1, kwrest: -1])
[ 2] a<Arg>     [ 1] b<Arg>     
0000 trace            8                                               (  27)
0002 trace            1                                               (  28)
0004 getlocal_OP__WC__0 4
0006 getlocal_OP__WC__0 3
0008 opt_plus         <callinfo!mid:+, argc:1, ARGS_SIMPLE>, <callcache>
0011 trace            16                                              (  29)
0013 leave                                                            (  28)
```

The Rubinius format is very nice and simple.

```
0000:  push_local                 0    # a
0002:  push_local                 1    # b
0004:  send_stack                 :+, 1
0007:  ret
```

The JRuby format looks complex, but partly this is just becuase it is
register-based and the dataflow is made more explicit.

```
[DEAD]%self = recv_self()
%v_0 = load_implicit_closure()
%current_scope = copy(scope<0>)
%current_module = copy(module<0>)
check_arity(;req: 2, opt: 0, *r: false, kw: false)
a(0:0) = recv_pre_reqd_arg()
b(0:1) = recv_pre_reqd_arg()
line_num(;n: 27)
%v_3 = call_1o(a(0:0), b(0:1) ;n:+, t:NO, cl:false)
return(%v_3)
```

The RubyJIT format is similar in simplicity to the Rubinius format, except that
it makes a few things more explicit, such as loading arguments into local
variables. it also includes `trace` instructions, which Rubinius does not have
as it does not support `set_trace_func`.

```
 0  arg       0
 1  store     a
 2  arg       1
 3  store     b
 4  trace     27
 5  trace     28
 6  load      a
 7  load      b
 8  send      +   1
 9  trace     29
10  return
```

### More technical details

There is [research](stack-register) into whether stack or register bytecode
formats are better. These often look at how much memory they use or how
efficient interpreters for them are. We aren't interested in either of these two
things in RubyJIT. Memory isn't a concern for a demonstrator project like this,
and for performance we use our just-in-time compiler rather than an interpreter.

[stack-register]: https://www.usenix.org/legacy/events/vee05/full_papers/p153-yunhe.pdf

Examples of projects using stack-based bytecode formats include the JVM, the
.NET CLR, CPython. Examples of projects using register-based bytecode formats
include LLVM, Parrot, and Lua. It tends to be that higher-level systems use
stack-based bytecode and lower-level systems use registers, but it isn't clear
if there a good reason for this. Some people, such as the JRuby and Parrot
developers, think it's easier to apply optimisations to a register-based format
because there is more experience doing this, but by the time the program gets
into the optimiser the difference between registers and the stack is long-gone.

### Potential projects

* Try designing and switching to a register bytecode format.
