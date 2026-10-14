# v102: PDP-6 native MM+VM relocation with pin and u-area tests

`run-v102.sh` extracts production `vm_extent_move` and filesystem word-copy
assembler bodies on every run, and links them with production `mm_pdp6.s`
in the PDP-6 simulator. Run with `DAIMOS_REPO=/path/to/DAIMOS`.

Cases include 512-word full relocation pattern verification, MM and VM base
publication, PI balanced restoration, rejection of current/transition/
unaligned/mapping-held moves, and newly added successful stable-uarea
runqueue stop/restart plus pinned MM extent exclusion. Runqueue and PI
callbacks are instrumented fixtures, not production scheduler execution.
