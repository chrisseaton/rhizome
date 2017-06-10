# RhizomeRuby

## Deoptimisation

Deoptimisation is perhaps *the* key technique for optimising a language such as
Ruby. It means jumping from optimised compiled back into the interpreter. This
allows you to only compile code for the simple and expected code paths, but
still be able to handle the unexpected code paths if they turn up.

### Why we need it

In the code that we compiled for the simple add method, we had multiple code
path branches to deal with different combinations of types. For example, when we
ran the add method in the interpreter with the profiler we saw that the method
was only being called with the `fixnum` kind, so we expect that to continue to
be the case in the future and we inlined the code for that case into the
method's compiled code.

However the way that the program is running may change after we have compiled
the method, and it may see `Float` values for the first time. To handle that we
checked the kind of the values to see if they really were `fixnum`, and if they
weren't we compiled in a normal method call to `#+` that can handle any types as
a backup. We call this backup call the *slow path*. The call works correctly for
all types, but it isn't quite as fast as the code we inlined specifically
for `fixnum` kind values.

The problem is that this slow path has an impact on the performance of the
method, even when it is never taken, for a couple of reasons.

Firstly, it increases code size. We have to compile the code to make the call to
the slow path even if we never end up using it.

Secondly if you branch between a fast path and a slow path and then merge the
two paths to continue in the rest of the method, the code that follows needs to
be able to handle whatever the slow path may have done. In our example above of
adding two values and the `Float` case being slow path, the code that follows a
branch between `fixnum` and `Float` will itself then have to handle both types
in the result.

Perhaps it would be possible to not merge back into the fast path after taking a
slow path if we were to duplicate all the code that follows each branch, but
this would increase code size exponentially for the number of branches.

### How it works

In this document we're going to introduce two parts of deoptimisation - transfer
from compiled code to the interpreter, and pruning uncommon parts of the graph
with transferring to the interpreter - but we'll develop deoptimisation further
to implement support for arithmetic overflow, monkey patching and tracing in
later documents.

#### Pruning uncommon parts of the graph

We said that the presence of the slow path branches alone, even when not taken,
had an impact on the performance of the method. Our solution is to prune this
code out of the compiler graph. In their place we leave a dead end, a *transfer
to interpreter* node. If control reaches this point in the graph the interpreter
will take over from the machine code and the machine code will not finish
executing.

After pruning we have a branch node with its condition, and on one side of the
branch is our transfer to interpreter. We further simplify this by turning the
branch node into a *guard* node. The guard checks the condition and transfers to
interpreter if it fails. The difference is that while a branch starts two new
basic blocks on either side, the guard node can sit within a basic block,
keeping the code for the fast path inside a single basic block.

The pruned branch never re-joins the rest of the program - it's a one-way
trap-door out of the compiled code. This means that we can also remove the point
where the two branches merged again, removing both the merge node and any phi
nodes.

This solves the two problems we had with the slow-path branches - we've removed
the slow-path code so the machine code is smaller. We have also removed the
merges from the slow-path, so code following the split between the fast and slow
paths only has to consider what kinds of values the fast-path code produces.

The slow-path branches are identified in the graph by the first node being
annotated with the property `uncommon`. Any other phase can insert this
annotation where they think it makes sense. The inline caching optimisation pass
adds it on the uncached fallback case. We could also extend the profile to
record which source-code level branches are taken and which aren't, and then
mark branches which it has never seen taken as uncommon for pruning.

#### Transferring to the interpreter

We now need to implement the operation of jumping from the middle of a method
compiled to machine code, into the interpreter, and continuing to execute.

There are three problems we need to solve. We need to call from the compiled
code back into Ruby, we need to work out what method we were in and what
bytecode to start executing interpreter, and we need to work out what would have
been on the interpreter stack and in local variables at this point, had we
already been executing in the interpreter.

We already designed our interpreter to allow it to start executing in the middle
of a method if you can supply what the state of the interpreter would be at that
point, so that problem is already solved.

The guard nodes which replaced our branch nodes with one uncommon branch are
implemented like a branch in that the check a condition and then jump. The
condition is always set up so that the jump is only on the guard failing, and
the target of the jump is always later in the code. These two properties are
used as heuristics by the processor to predict that the branch will not be
taken, allowing it to speculatively keep executing code presuming that the guard
will not fail.

The code that the guard jumps to is always located at the end of the machine
code for the method, so that it never interrupts the stream of code for the fast
path. The code calls back into Ruby into a `continue_in_interpreter` method,
pushing any registers that contain live values, and passing it the current stack
pointer and a reference to a data structure called a *deoptimisation map*, which
will be described in the next section. When the call returns the compiled method
then also returns. This solves the first problem we said we had - calling back
into Ruby.

#### Deoptimisation maps

The *deoptimisation map* describes to the `continue_in_interpreter` method how
to find all the information it needs to start running the interpreter again. The
information needed is the bytecode instructions, the index of the instruction to
start executing at, the receiver, the arguments, and values which would have
been on the stack and in the local variable map in the interpreter.

The machine code stores values in registers and on the stack. The stack is just
memory, so the Ruby code can read it using either the FFI or Fiddle, the same
way it wrote the machine code to memory. We passed `continue_in_interpreter` the
address of the stack when we called it. The machine code also uses registers,
but we can push these onto the stack before deoptimising so that they can be
read as well.

The deoptimisation map then describes how to map from locations on the stack
into the receiver, arguments, stack and local variable names.

The remaining information needed - the bytecode instructions and the index of
the instruction to start executing at - can be stored as normal instance
variables in the deoptimisation map as are immutable.

Deoptimisation maps are created by the IR builder and they're initially a node
in the IR. Every node that could cause a side effect has an edge pointing to a
deoptimisation map node, which has edges pointing to the nodes that produce the
values it would need to continue in the interpreter. When optimisations are run
these edges are treated like any other, so they are updated by operations such
as global-value-numbering, and the edges are used by the register allocator like
any other edge would be to work out how long to keep values alive for.

The code generator keeps track of the most recent deoptimisation map node it has
seen. When it needs to emit code for a guard instruction it looks at the
deoptimisation map node and creates a new data structure that contains the
register for each edge containing a value that went into the deoptimisation
node. It uses the same information to emit code to push onto the stack all the
registers that were used by these edges.

Finally, it converts the deoptimisation map Ruby object to a native handle and
emits code to pass that and the stack pointer as arguments to a call to the
`continue_in_interpreter` method which will read all this information back off
the stack.

One thing that it is important to realise here is that there is no problem if
the interpreter re-does some work that the compiled code already did, as long as
side effects - effects that are visible to the user such as writing to files -
are not repeated. If you are adding three numbers together, and you transfer to
the interpreter on the second add, you can start adding from the beginning
again, and have a simpler deoptimisation map. We call this *rolling back*.

The code generator only updates its reference to the most recent deoptimisation
map when it has seen a side effect since the last time it updated. This rolls
back the deoptimisation map as far as we can. We also deduplicate deoptimisation
maps if they come from different places but actually contain the same values
(possibly due to our rolling back).

Due to side effects and rolling back, the complexity of deoptimisation isn't
visible in our usual simple `add` function example.

```ruby
def add(a, b)
  a + b
end
```

This method has the following bytecode:

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

If the types were not as expected at the point of the add operation, we can roll
all the way back to the start of the method because there are no side effects
between the two points. The deoptimisation map points at the Ruby method, but
the bytecode index is `0` and the stack and local variables are simply empty.

Let's modify our example to include a call with side effects.

```ruby
def side_effect(n)
  # ... some operation here which has some side effect - we don't care what ...
  n
end

def add_with_side_effects(a, b)
  side_effect(a) + side_effect(b)
end
```

`add_with_side_effects` has this byteocde:

```
0  arg      0
1  store    a
2  arg      1
3  store    b
4  trace    8
5  trace    9
6  self
7  load     a
8  send     side_effect   1
9  self
10 load     b
11 send     side_effect   1
12 send     +     1
13 trace    10
14 return
```

Now the method calls `side_effect(a)` and then `side_effect(b)` and go to
perform the add, but if at that point we find that the types are not what we
expected will want to transfer to interpreter. However, because the two calls to
`side_effect` have already run and they have side effects so we can't roll back
to the start of the method like we could in the previous example. When we
transfer we now need to begin at bytecode `12`, we need the two arguments stored
in their local variables, and we need to have `self` and the result from the two
calls to `side_effect` already on the stack, ready to go.

The lowered code just after linearisation for this method looks like this:

```
arg 1 rdx
self rdi
constant side_effect r8
arg 0 rsi
call_managed rdi r8 rsi r9 [:RDX, :RDI, :R8, :RSI]
int64_shift_right r9 1 r10
int64_and r9 1 r11
call_managed rdi r8 rdx r8 [:RDX, :RDI, :RSI, :R9, :R10, :R11]
int64_shift_right r8 1 rbx
int64_and r8 1 r12
deopt_map 12 rdi [:rsi, :rdx] [:r9, :r8]
guard r11 int64_not_zero?
guard r12 int64_not_zero?
int64_add r10 rbx r12
int64_shift_left r12 1 rbx
int64_add rbx 1 rbx
return rbx
```

If either of those guards fail we need to continue in the interpreter after the
calls to `side_effect`, so at instruction 12 (the `send +`) at the latest. We
can see that the receiver would be in `rdi`, the two arguments in `rsi` and
`rdx`. The values on the stack would be the result of the calls to
`side_effect`, so `r9` and `r8`.

The deoptimisation routine therefore pushes these values onto the stack and
calls `continue_in_interpreter` with the values of the frame pointer `rbp`, the
stack pointer `rsp` and the handle for the deoptimisation map.

```
0x0000000105a8a0a4  push %rdi                     ; 57
0x0000000105a8a0a5  push %rsi                     ; 56
0x0000000105a8a0a6  push %rdx                     ; 52
0x0000000105a8a0a7  push %r9                      ; 41 51
0x0000000105a8a0a9  push %r8                      ; 41 50
0x0000000105a8a0ab  mov %rbp %rdi                 ; 48 89 ef
0x0000000105a8a0ae  mov %rsp %rsi                 ; 48 89 e6
0x0000000105a8a0b1  mov 0x3ffe870b7dd4 %rdx       ; 48 ba d4 7d 0b 87 fe 3f 00 00
0x0000000105a8a0bb  call -4288 (0x0000000105a89000 continue_in_interpreter) ; e8 40 ef ff ff
```

The stack now contains the values from these registers, plus previous values from this method but we will ignore them.

```
[..., rdi, rsi, rdx, r9, r8]
```

The deoptimisation map contains this information:

```
  bytecode: ....
  ip:       12
  receiver: first value
  args:     2 values
  stack:    2 values
  locals:   {}

```

We map the two together by popping off the machine stack 2 values for the interpreter stack.

```
[..., rdi, rsi, rdx] -> [r9, r8]
```

Then two values for the arguments.

```
[..., rdi] -> [rsi, rdx]
```

Then a value for the receiver.

```
[..., ] -> rdi
```

We convert all these values from native to managed, so removing tagging and
possibly converting handles to references, and we then have all the information
we need.

### More technical details

Some of the terminology in this area can be confusing. We've said that it's one
form of deoptimisation, but some people would reserve that word for a technique
we are going to describe in the next document, *safepoints* and polling for
deoptimisation. Another term is *uncommon trap*, where *trap* refers to the
trap-door out of the machine code into the interpreter and *uncommon* is their
way of saying slow-path.

Deoptimisation maps are sometimes called *frame states* or *stack maps*, the
latter term also being used to talk about objects that describe the stack for
precise garbage collectors that want to understand where they may find
references to objects on the stack.

### Potential projects

* Profile which source-code level branches are never taken in the interpreter
  and annotate them as uncommon so they are pruned.
