# RhizomeRuby

## Code generation

Code generation takes a lowered, scheduled and register-allocated graph,
linearised by the scheduler, and emits machine code instructions to the
assembler.

The lowering process has already worked towards making each node in the graph
correspond to a single machine code instruction, but in some cases the code
generator emits sequences of instructions for more complicated operations, and
for the prelude of a method.

### Why we need it

We need to go from the graph data structure to a linear sequence of machine code
instructions. The linearisation pass of the scheduler can already put nodes into
a linear order. We just need an extra part to go through those nodes and ask the
assembler to emit instructions for each one.

In many compilers, code generation is a substantial part of the backend. We have
tried to keep as much work as possible on our single graph intermediate
representation data structure, so our lowering pass already converts most nodes
to correspond to a single machine code instruction, and our actual code
generation is very simple and usually just asks the assembler to emit the
instruction for that node. Sometimes a node represents a more complex operation
and the code generator will emit more instructions, almost like a little inline
subroutine from its library.

### How it works

The code generator accepts a linear sequence of instructions from the scheduler.
It expects that the instructions were lowered, scheduled, and
register-allocated.

The code generator begins by emitting a set of instructions that always begin a
method, which is called a *prelude*. The code generator then loops through the
instructions, emitting machine instructions to an assembler for each.

### More technical details

Rhizome doesn't really tackle the more interesting problem of good instruction
selection. Instruction sets like AMD64 are very complicated and there are many
ways to achieve the same result with different combinations of instructions.
Rhizome just emits instructions for each node that will do the job from a small
set of options. A more sophisticated code generator will look at multiple
operations at the same time and consider how the overall effect that is wanted
could be achieved with less instructions than operations. One technical involves
looking at the instructions available on the processor as a set of templates and
scanning over the graph seeing where they could fit over sets of nodes.

In the document describing lowering we said that we passed the
convert-immediates pass a list of patterns describing which instructions could
take immediate values. This is a bit like this idea of a set of templates.

Instruction scheduling is another interesting problem that we haven't tackled in
Rhizome. We've scheduled the graph, finding out when one node must have run
before another and encoding that, but we haven't considered what to do with the
remaining freedom we have to schedule nodes that don't have further constraints.
If we used knowledge of how the processor works internally - how many arithmetic
units, or how much memory bandwidth it has, for example, we could order
instructions to try to pack instructions into those resources as efficiently as
possible. Not only are the algorithms for this complicated, but they rely on
extremely sophisticated knowledge of the internal architecture of particular
models of processors.

To give you an idea of the scale of the complexity, Intel publishes a 690-page
[Software Optimization Reference Manual](manual) explaining how to produce
efficient code for their processors.

[manual]: https://software.intel.com/en-us/articles/intel-sdm

Just-in-time compilers have an advantage here, in that they can look at what
processor you really have an adapt their code generation to it, rather than
having to emit code that works reasonably well on a wide range of processors.

### Potential projects

* Implement a basic instruction selection algorithm.
* Implement a basic instruction scheduling algorithm.
