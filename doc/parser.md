# RubyJIT

## Parser

The RubyJIT parser isn't a parser for Ruby source code. Instead, it's a parser
for the internal bytecode formats used by different implementations of Ruby.

This is very important, because it allows us to not have to worry about parsing
a complex language in this project. The bytecode formats of the different
implementations of Ruby have already handled that complexity for us.
Traditionally, programming languages have been presented as being very much
about parsing. The major text books and many amateur blog posts spend many
chapters talking about lexing and parsing. They often finish just when they get
to what we think is the more exciting bit - actually optimising and generating
machine code.

Each Ruby implementation has a different internal bytecode format, so we
actually have one parser corresponding to each implementation. They use simple
regular expressions to translate the different formats to the RubyJIT bytecode
format, described in another document.

### Why we need it

The RubyJIT parser takes the multiple bytecode formats used by the different
Ruby interpreters, which have different design goals and technologies, and
translates them into the single, simpler, more explicit format of the RubyJIT
bytecode.

### How it works

Bytecode formats are regular, in the formal linguistic sense. That means that
they have no nesting, and instructions never contain other instructions. They
just come in a sequence. If an instruction uses data from one or more other
instructions, then those instructions store their data to some kind of variable,
and the subsequent instruction loads from that variable. This regularity means
that parsing bytecode is not complicated. Regular expressions are a simple form
of parser designed only to handle regular languages, so they are sufficient for
what we need.

We compare each line of bytecode against a list of regular expression patterns,
extract the information we want such as the instruction name and the name of
local variables or the value of numbers, and build a new list of instructions in
our own RubyJIT format.

#### Two-pass parsing

The only minor complexity is that we need to re-map the way that instructions
are addressed when they are the targets of jump and branch instructions. MRI and
Rubinius use the actual byte offsets of instructions relative to the start of
the method. JRuby uses more formally named labels that appear in the bytecode
like additional instructions.

RubyJIT uses the simpler addressing system of the instruction index, discounting
how many bytes they may need if they were ever serialised.

The problem is that jumps and branches usually go forward in the stream of
instructions. In that case you know the address of the instruction in the input
bytecode format, but you don't know how many more instructions there until you
see that address and so you don't know what to translate it to.

We therefore use a two-pass system where jump and branch target addresses are
left as-is on the first parse, and a map is built of old addresses to new
addresses. At the end, when the map is complete because all instructions have
been seen, all the jump and branch targets are updated.

#### Parsing MRI's bytecode format

To access MRI's internal bytecode for a method we use
`RubyVM::InstructionSequence.disasm(method(:name))`. Run
`experiments/bytecode/print_bytecode_mri.rb` to see what this produces.

Instructions are matched by regular expressions and transliterated almost
one-for-one from the MRI format to the RubyJIT format. In many cases they are
generalised, translating many variants to a single generic variant. In some
cases instructions expand to become two instructions, such as `branchunless`
becoming `not` and then `branch`.

#### Parsing Rubinius' bytecode format

To access Rubinius' internal bytecode for a method we use
`method(:name).executable.decode`. This gives us a rich data structure, but we
actually just turn that straight into text and parse it from there. This means
that the parser code works and can be tested on any Ruby implementation. Run
`experiments/bytecode/print_bytecode_rbx.rb` to see what this produces.

Instructions are transliterated much as in MRI.

Rubinius doesn't support `set_trace_func` (it does suggest its own alternative
tooling), so the Rubinius bytecode doesn't include `trace` instructions that
tell us when the interpreter reaches a new line of source code. It does provide
a mapping from bytecode instruction offsets to lines of code, and we
experimented with restoring `trace` instructions from this information, but then
we realised that we wouldn't be able to use them anyway as Rubinius itslef
doesn't have the feature.

#### Parsing JRuby's bytecode format

To access JRuby's internal bytecode for a method we use JRuby's Java
interopability and the Java reflection mechanism to reach directly into the Java
data structures that make up JRuby, calling
`method(:name).to_java.get_method.ensure_instrs_ready.get_instructions`. As in
Rubinius this returns a rich data structure, but we just convert that to text
and parse from there. Run `experiments/bytecode/print_bytecode_jruby.rb` to see
what this produces.

JRuby's bytecode format is register-based, and RubyJIT's format is stack-based.
We use a simple solution to this problem, and treat each of JRuby's registers as
if it were a local variable. This means that RubyJIT bytecode created from JRuby
bytecode is much larger than from MRI or Rubinius, often with many redundant
loads and stores of these local variables.

For if the result of a call operation is used in another call it will be stored
and then immediately loaded again, sometimes in one instruction after another.
This would be a problem if we needed interpretation to be fast or were worried
about storage space, but we are using our just-in-time compiler for speed, and
it will easily remove these redundant loads and stores.

### More technical details

We really do think that parsing is the least interesting part of compilers and
virtual machines. This project uses a parser from the bytecode of the existing
Ruby implementations in order to avoid that and let people get to the more
interesting parts more quickly.

Among academics it may be controversial to say that parsing is a solved problem,
but we think it's reasonable to say that it is in the context of a language like
Ruby.

Our parsers are very simple and they will likely break with most methods that we
haven't tested them with. As we've said, we don't think parsing is very
interesting so in this part of the project we just did the minimum to get going.

### Potential projects

* Restore `trace` instructions in the Rubinius parser.
* Implement your own parser from Ruby source code, perhaps using one of the
  Ruby parser gems.
* Implement a parser for the serialised bytecode file format that Rubinius
  uses.
