# v105: two process relocations in one native PDP-6 compaction

Runs the actual MM and extracted exact production VM/word-copy assembler via
`p10run --machine pdp6`. In the new scenario, two sleeping process extents
with distinct owners and full 01000-octal-word payloads must relocate past
three pinned extents and across two managed arenas before a 04000-word
contiguous allocation becomes possible. Assertions verify both relocated VM
bases, balanced PI hooks, five intact descriptors, and every copied word.
The v104 single-process and negative-state regressions remain included.

Independent PI/runqueue interfaces are instrumented fixtures, not the
running kernel scheduler. Full scheduler integration remains open.
