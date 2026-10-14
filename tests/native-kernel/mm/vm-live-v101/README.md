# v101 standalone PDP-6 production MM/VM relocation

Run `DAIMOS_REPO=/path/to/DAIMOS ./run-v101.sh`. This executes real
`mm_pdp6.s`, extracts `vm_extent_move` and `fs_move_words` unchanged from
production assembler, and runs the result under `p10run --machine pdp6`.
Only unrelated PI/scheduler service hooks are fixtures.

An independently generated XOR pattern checks **all 01000 octal words**
of the relocated extent, plus MM descriptor and process VM base updates.
Negative cases check current process, TRANSITION, unaligned destination,
and held translated user mapping. Native simulator: PASS.

Outstanding: real runqueue and u-area stop/restart, interrupt concurrency,
pin exclusion and repeated fragmented/overlapping relocations.
