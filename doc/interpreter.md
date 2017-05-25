# RhizomeRuby

## Interpreter

The Rhizome interpreter executes Ruby code expressed in our bytecode format.

We use the interpreter for two purposes. First, we use it to gather information
about how your program really behaves when it executes. This is information that
is often not possible to determine through static analysis, such as which values
are types are flowing through the program, and which branches are being taken
with which frequency. We'll use this information later when the compiler runs.

Secondly, we use it to continue to execute programs when the just-in-time
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

```ruby
def interpret(insns)
  ...
  loop do
    insn = insns[ip]
    case insn.first
      ...
      when :load
        stack.push locals[insn[1]]
        ip += 1
      ...
      when :store
        locals[insn[1]] = stack.pop
        ip += 1
      ...
    end
  end
end
```

#### Profiling

The interpreter can be passed a profile object, which stores information about
what the code is doing in practice. For example, we profile the kinds of the
receiver and the arguments to each `send` instruction. I say *kind* rather than
*class*, which is a word used in different ways to express abstractions of class
or types, because really we capture a little more information than just the Ruby
class. For the `Integer` class we capture whether the value is a tagged pointer
(a `Fixnum` in Ruby 2.3 terminology) or an unbounded integer (a `Bignum` in
2.3).

If we run the interpreter on a simple `fib` function which looks like this:

```ruby
def fib(n)
  if n < 2
    n
  else
    fib(n - 1) + fib(n - 2)
  end
end

fib(10)
```

And has bytecode like this:

```
 0  arg      0
 1  store    :n
 2  trace    31
 3  trace    32
 4  load     :n
 5  push     2
 6  send     :<     1
 7  not        
 8  branch   12
 9  trace    33
10  load     :n
11  jump     24
12  trace    35
13  self       
14  load     :n
15  push     1
16  send     :-     1
17  send     :fib   1
18  self       
19  load     :n
20  push     2
21  send     :-     1
22  send     :fib   1
23  send     :+     1
24  trace    37
25  return
```

Then this is the profiling information that we will gather:

```
#<struct Rhizome::Profile::SendProfile ip=6, receiver_kinds=#<Set: {:fixnum}>, args_kinds=[#<Set: {:fixnum}>]>
#<struct Rhizome::Profile::SendProfile ip=16, receiver_kinds=#<Set: {:fixnum}>, args_kinds=[#<Set: {:fixnum}>]>
#<struct Rhizome::Profile::SendProfile ip=17, receiver_kinds=#<Set: {Object}>, args_kinds=[#<Set: {:fixnum}>]>
#<struct Rhizome::Profile::SendProfile ip=21, receiver_kinds=#<Set: {:fixnum}>, args_kinds=[#<Set: {:fixnum}>]>
#<struct Rhizome::Profile::SendProfile ip=22, receiver_kinds=#<Set: {Object}>, args_kinds=[#<Set: {:fixnum}>]>
#<struct Rhizome::Profile::SendProfile ip=23, receiver_kinds=#<Set: {:fixnum}>, args_kinds=[#<Set: {:fixnum}>]>
```

This tells us that, for example, the `send` instruction at instruction pointer
(`ip`) 21 has been called with a receiver and one argument that have both always
been tagged pointer integers.

When we compile we'll use this information.

#### Resuming execution

A second interesting feature of our interpreter is that it allows you to begin
execution of a method at any point, with any state - the state being the current
stack and the value of all local variables. However this isn't complicated to
implement. We make the instruction pointer, stack and local variable map
parameters and give them empty default values for the case when we don't want to
start the interpreter beyond the start.

### More technical details

There aren't many interesting technical things to say about the interpreter!
It's as simple as described and the extra features of profiling and being able
to start execution at any point only add a couple of lines.

### Potential projects

* MRI stores caches alongside instructions to speed up `send` instructions in
  its interpreter. Add these caches to our interpreter, so that `send`
  instructions which always see the same class don't need to look up the method
  to call each time.
* Gather and use more profiling information, such as which branches are taken
  which what probability.
