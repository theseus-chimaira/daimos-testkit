# Native DAS spill-backed DOBJ1 global metadata v1405

The v1405 increment transports global symbol metadata through the
private DASIR2 phase file.  Native DAS1 stores global declarations in
the existing spill-backed symbol records using a distinct hash
namespace.  The record value contains a stable one-based DOBJ symbol
index.  Duplicate `.globl` and `.extern` declarations reuse the same
index.  `.entry` records the corresponding index, and `.comm` stores
a public BSS symbol.  No second resident name table is allocated.

The private DASIR2 state now contains the global count and entry
index.  DAS2 validates the serialized marker order and exact count
when rebuilding the spill-backed symbol table.  A missing, duplicated,
or reordered marker is rejected rather than mapped to a wrong DOBJ
symbol index.

The five native PDP-6 probes require a successful C89 compilation and
unchanged DXR output, then exercise both a KCC-produced `.globl main`
and a separate assembly fixture declaring three globals (including
duplicate names), an external symbol, a common BSS symbol and an
explicit entry.  Both native DAS1/DAS2 invocations expose their
verified metadata counts in compact `GddddddEdddddd` octal form
before safely rejecting the unfinished relocatable output.  A
nonexistent output cannot masquerade as DOBJ1.

The native DOBJ1 writer and relocation records remain unfinished;
the `-C` safety gate is intentionally retained.  This milestone is
phase metadata correctness, not full self-hosting acceptance.
