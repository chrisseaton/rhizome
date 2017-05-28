# RhizomeRuby

## Optimisations

It used to be the case that people talked about *optimising compilers* as a
separate thing to conventional compilers, because not all compilers applied
optimisations. Today it's pretty rare to see a compiler that doesn't do any
optimisations, and we'd talk about them as being a *template compiler*. The
first tier of the V8 JavaScript JIT compiler, called *fullgen* is a template
compiler. These days the analysis and transformation that compilers do
completely break down your program and build it up from scratch again to
generate code from it, so that the line between optimisations and the basic
pipeline of the compiler is blurred. It doesn't feel quite right to talk about
techniques such as inline caching or register allocation as optimisations -
they're essential and routine parts of the compiler.

Rhizome does include some passes that aren't quite as integral to the
compilation process, which we describe in this document.

### Why we need them

Optimisation passes take a graph and modify it to do the same thing but more
efficiently. For a language such as Ruby, making the graph more efficient could
be the difference between compilation generating code that is so verbose that it
runs slower than a basic interpreter, and actually producing something that
makes the compilation worthwhile.

### How they work

#### Global value numbering

*Global value numbering* is an optimisation to avoid computing the same value
twice. It is a form of *common subexpression elimination*. The *global* part of
the name means that it applies between basic blocks, not that it is applied
globally across your entire program. Common subexpression elimination means
finding expressions like this:

```ruby
b = a * a + a * a
```

And eliminating the duplication of the common part of the expression by
computing it once and storing it in a temporary.

```ruby
temp = a * a
b = temp + temp
```

When we write it like this the transformation looks like it makes our program
more complicated - we've introduced a new name and a new instruction. One of the
great things about the sae-of-nodes approach of the Rhizome intermediate
representation is that.

(diagram of before)

In our graph the `+` operation has two edges coming into it that compute the
same value. We know that they compute the same value because they both lead to a
node with the same operation that itself has edges going to same input values,
or nodes that themselves go to the same input values, or so on. We can remove
the duplicated computation by simply pointing the two inputs of `+` to one of of
the two identical nodes.

(diagram of after)

To find duplicated nodes that idea is that you give each node a number that is
somehow computed from the operation and the inputs. If two nodes have the same
number then they do the same thing. In practice nodes have methods to compare
equality, a hash code that is like the value number but doesn't have to be
unique, and duplicates are found by looking up in a hash.

Rhizome anticipates that global value numbering will be run later when building
the graph. This allows the graph builder to be a bit simpler. For example the
graph builder emits a new `arg` node each time an argument is referenced,
creating multiple `arg` nodes. Global value numbering then tidies this up
afterwards to use a single `arg` node for each argument number. The same applies
to constants that we need - we emit them nodes for constants without worrying
about whether the value already available in the graph, and let global value
numbering sort it out afterwards.

In practice this is less work when writing the earlier phases, but more work for
the later phases and the garbage collector because we generate larger graphs. It
also makes understanding the intermediate graphs more complicated as they have
redundancy hanging around in them. It may be better to keep the graph tidy as it
is built.

#### Constant folding

*Constant folding* means computing values during compilation rather than at
runtime, where possible. *Folding* refers to collapsing multiple nodes into a
single constant value node, however the actual applications be a little more
interesting than that.

The basic algorithm for constant folding is very simple - we look at each node
and its inputs and they're all constants then we can take their values,
calculate the result, and replace the node with a constant value of the node.

You may not think that you often write code such as `14 + 2` that can clearly be
constant folded, but more constant expressions tend to appear after passes such
as inlining and lowering run.

In some cases we can constant fold even when the inputs aren't constant
themselves, just by looking at what the inputs are doing. For example an
`is_tagged_fixnum?` node that has an input that is a `tag_fixnum` can be
replaced with a `true` value. The result of `tag_fixnum` isn't a constant, but
the property that we care about - that it is a tagged fixnum - is constant.

#### Re-float nodes

When we inline method sends we always feed the control-flow path from where the
send was into the body of the method, and out of it to where the return was, as
we don't look at whether the body of the method has any side effects or not. It
also have side effects to start with, and these can be removed later through for
example removal of redundant guards.

This can leave us with nodes that don't have any side effects, such as basic
arithmetic operations, being fixed in control flow. That then prevents other
optimisations apply to them, such as global value numbering.

For example, in the redundant multiply example after method send inlining we are
left with two `fixnum_mul` nodes. These have the same inputs so would hope that
they would be unified into one. However they have different control-flow inputs,
which makes them appear to be different.

The re-float pass finds nodes such as these - nodes that are fixed but don't
have side effects - and removes them by re-routing control-flow around them. 

#### The pass runner

When an optimisation pass runs it may create new nodes which could be further
optimised by other optimisation passes, or even by the same pass again. It isn't
clear if we can know exactly which passes will do something useful if we run
them, so in Rhizome we have a have a runner that takes a list of passes and will
keep running all of them until they have all run for a final time and made no
changes. Optimisation passes are responsible for telling the runner if they made
any changes.

This is probably pretty inefficient and to improve compilation time in a
production system you may want to more carefully work out what optimisation to
run at what point in compilation.

### More technical details

There's an interesting question of where to put code for optimisations. We've
chosen to group by functionality, so that all the code for constant folding is
in one file, and all the code for removing redundant guards in another. An
alternative would be to create subclasses of `Node` for the different operations
instead of using an `op` field, and then adding methods to those classes for the
nodes to optimise themselves. For example all methods could have a
`constant_fold` method and an `AddNode` subclass could implement it to look at
its inputs and replace itself.

This is a bit like the *expression problem*, which talks about whether you want
it to be easy to add new data types, or easy to add new operations on them. If a
data type is is defined within just one file it's easy to add new data types,
but it's hard to add new operations because you need to modify every file with a
data type in it. If all the implementations of an operation for all data types
are defined within just one file it's easy to add a new operation, but it's hard
to add a new data type, because you need to modify every file with an operation
in it. The expression problem talks about this in terms of separate compilation
but we think it makes sense in terms of writing and reading code as well.

We chose to group by functionality because makes it easier to read for learning.

### Potential projects

* Figure out how to be more intelligent about which optimisations to run at
  what time.
