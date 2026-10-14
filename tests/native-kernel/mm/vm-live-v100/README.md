# v100 production VM/physical-copy PDP-6 regression

`run-v100.sh` extracts `vm_extent_move` from the current production
`vm_pdp6.s` and `fs_copy_words`/`fs_move_words` from `fs_mres.s` at
build time. It links those exact assembler instructions with production
`mm_pdp6.s` in `p10run --machine pdp6`. Only PI, runqueue and other
independent OS services are stubs. No full kernel bootstrap is necessary.

Cases: successful upward MM+VM relocation with two physical payload
endpoints and process/extent base validation; current-process rejection;
TRANSITION rejection; and balanced PI hooks. Assertions give independent
failure exit codes. This does not exercise live runqueue/UAREA, translated
mapping exclusion, every interior payload word, interrupts or full OS boot.
