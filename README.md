# Rhizome - a JIT for Ruby, implemented in pure Ruby

![graph of a simple add function](logo/rhizomeruby-small.png)

Rhizome is a paedological just-in-time compiler (JIT) for Ruby, implemented in pure Ruby. It's not really designed to be used. It's designed to show you how JITs work and why perhaps a JIT for Ruby should be written in Ruby. It's also designed to try to go beyond the trivial aspects of a simple template compiler that introductions to JITs often show - instead it has a proper intermediate representation (IR) and shows how more advanced parts of compilers such as lowering and schedulers work, that people don't usually cover.

Unforutnately Rhizome was a stalled side-project that I never finished. The current state of the repository is as I left it off.

By [Chris Seaton](https://chrisseaton.com).

## How to read this repository

You're supposed to read it, not use it!

There are *experiments* and *documents*. The experiments are little programs that show you how one part of the system works, often generating graphs as output, and the documents explain things in more depth with some references and some ideas for readers.

To run an experiment run `bundle exec experiments/foo.rb`. It'll either show some output or will generate a graph. Then also read it.

The recommended reading order is:

* [Parser](doc/parser.md)
* [Bytecode](doc/bytecode.md)
* [Interpreter](doc/interpreter.md)
* [Inline caching](doc/inline-caching.md)
* [Intermediate representation](doc/ir.md)
* [Construction](doc/construction.md)
* [Graphviz](doc/graphviz.md)
* [Optimisations](doc/optimisations.md)
* [Inlining](doc/inlining.md)
* [Handles and tagging](doc/handles-tagging.md)
* [Lowering](doc/lowering.md)
* [Scheduler](doc/scheduler.md)
* [Code generation](doc/codegen.md)
* [Registers](doc/registers.md)
* [Memory](doc/memory.md)
* [Assembler](doc/assembler.md)
* [Disassembler](doc/disassembler.md)
* [Deoptimisation](doc/deoptimisation.md)

I'm very sorry it's not more polished! Hopefully you can get something out of it.

## Running

```
% brew install graphviz
% bundle install
% bundle exec rspec
```

## Licence

Copyright (c) 2016-2017 Chris Seaton. Available under the MIT licence.
