# v103 PDP-6 native MM+VM relocation across disjoint arenas

`run-v103.sh` extracts exact production `vm_extent_move` and resident
`fs_move_words`/`fs_copy_words` assembler, links the real MM assembler,
and executes under `p10run --machine pdp6`. Run with
`DAIMOS_REPO=/path/to/DAIMOS`.

The new cross-arena case moves a process from the first managed physical
arena into a suitable higher gap in a second arena. It checks sorted
extent descriptors, unchanged descriptor count, updated process VM base,
512-word full payload preservation and PI balance. Existing tests cover
single-arena relocation, stable u-area stop/runqueue callbacks, pinned
exclusion and several rejection conditions. PI/runqueue hooks are still
instrumented fixtures; no complete kernel boot is asserted.
