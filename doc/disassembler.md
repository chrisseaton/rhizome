# RubyJIT

## Disassembler

The RubyJIT disassembler is the reverse of the assembler. It takes binary
machine code and gives you a human-readable assembly code that can be printed to
the screen.

### Why we need it

Inside RubyJIT there is never a textual representation of the assembly code that
we generate. The code generator calls methods on the assembler which builds up
an array of machine code bytes. In a conventional static compiler, the code
generator often generates a text stream that is then fed into the assembler, in
human-readable assembly code text syntax. If you want to read the assembly code,
you can just get that text stream.

RubyJIT doesn't generate an intermediate text format because we run everything
inside the Ruby process and so we can communicate between stages of our compiler
using objects.

So if we do ever want to read the assembly code that RubyJIT produces then we
need to have a tool to reproduce it from the binary machine code. This is what
the disassembler does.

Just-in-time compilers are also unlike most static compilers in that the machine
code may in some cases be modified after it has been installed. In this case the
disassembler that works from the actual bytes is useful as it can tell us what
code is actually in memory, rather than what we intended to install originally.

### How it works

The disassembler is given an array of bytes and each time the `next` method is
consumes as many bytes as make up one instruction and produces assembly code as
text. You can keep getting the next instruction as long as there are more bytes.

As with our limited assembler, the disassembler only knows how to disassemble
exactly the instructions that we generate. Also, it doesn't generate assembly in
any proper format that you could directly feed into an assembler.

### More technical details

Our disassembler generates only basic assembly code. It would be possible to add
a lot more information. For example where one instruction jumps or branches to
another, a line could be drawn alongside the instructions to show where the
target is, or labels could be re-introduced to replace instruction address
offsets. Handles that have been compiled into the code could be inspected to
print what they are alongside the assembly code, and instructions could be
mapped back to source code line numbers to explain where the instructions have
come from.

### Potential projects

* Generate labels in the assembly code for jump and branch targets.
* Show jumps and branches with a line linking the instruction and the target.
* Comment instructions with the Ruby line number they came from.
