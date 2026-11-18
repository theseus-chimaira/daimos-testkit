# v1661 source-linked PDP-6 compressed PURE terminal proof

Run with clean pushed v1660 DAIMOS and testkit trees:

    DAIMOS_REPO=/path/to/DAIMOS PDP10_PREFIX=$HOME/cross \
      TMPDIR=$HOME/tmp \
      sh tests/validation/pure-bitmap-terminal-v1661/run-v1661.sh

The default runner executes the entire v1660 native decoder and
v1659 real-MM baseline first. For development-only quick reruns set
`V1661_SKIP_BASELINE=1`; never use this for release evidence.

The test links the new actual C89 terminal leaf with the **original**
PDP-6 MM assembler's `mm_find_base`, `mm_delete` and `mm_free`.
The scanner and delete sequence are mechanically extracted from
DAIMOS source; a source-shape drift refuses the test. Only PI state
is controlled by a fixture: the real hardware PI instruction is
not represented by this unit regression.

Mode3 represents a 161-word compressed owner for a 3,456-word RAW
logical suffix, still backed by the same immutable text record and
stable u-area. Its physical length is derived solely from the one
MM PACKED_PROCESS owner, not from a permanent registry. Under the
test PI exclusion, terminal success frees that exact owner via the
production MM assembly and clears mode3 to mode0. It retains the
original backing, u-area, and TRANSITION for `proc_swap_detach` to
complete in a future integrated implementation.

Eighteen refusal cases must leave the MM owner and storage mode
unchanged: RAW mode, wrong MM owner, duplicate, pinned, RAW-sized,
insufficient bitmap masks, conflicting backing, live APR, missing
transition, injected MM-free refusal, wrong MM type, FREE process,
missing MM descriptor, overrun of 18-bit physical core, invalid
descriptor capacity, negative MM extent count, reserved owner type,
and an extra reserved-type owner. An unrelated MODULE owner with
the same numeric ID survives correct compressed release. An owner ending
at the exact exclusive 01000000 octal physical limit is accepted.

An independently compiled and executed source mutant disables
both duplicate-owner checks. The real-MM test must reject it.

This is test-only. No actual kernel mode3 publication, RAW release,
bounded FULL restore or terminal wiring is installed. The fixed
KCORE still rejects mode3. No physical RAM savings are claimed.
