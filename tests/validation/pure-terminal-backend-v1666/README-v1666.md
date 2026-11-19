# v1666: source-linked PDP-6 terminal memory-backend selection

Parent DAIMOS commit v1665:
`08a31f16c1c5a7793e8bc59995efaed238954f31`.

Run native validation from the daimos-testkit checkout:

    DAIMOS_REPO=/path/to/DAIMOS PDP10_PREFIX=$HOME/cross \
      TMPDIR=$HOME/tmp \
      sh tests/validation/pure-terminal-backend-v1666/run-v1666.sh

This runs the entire historical v1609 native RAW teardown test,
including its executed unsafe backing-source mutation, before the
new tests. `V1666_SKIP_BASELINE=1` is for interactive debugging
ONLY. The testkit compiles the actual fixed KCORE
`proc_swap_detach()` C and source-extracts the genuine PDP-6
`proc_swap_mres_terminal_v1666` assembler, the original
`pdp6_pure_detach_v1609`, existing storage mode assembly and
`vm_space_destroy` leaf. No C implementation of the production
disk-release algorithm is substituted in native tests.

The genuine KINIT-installed terminal entry is represented in the
disk run by a direct JRST to the real disk MRES leaf. The historical
v1609 run uses an entry directed at the real PURE RAW leaf.
`proc_swap_minit_v481()` source-linked tests verify the third
PURE and eighth DISK export addresses and exact patch counts.

Twelve native disk/RESIDENT cases cover success, repeat detach,
refused free, accounting underflow, zero blocks, zero backing,
forbidden RAW mode2, forbidden compressed mode3, still-mapped
APR, SIDL mount-bit teardown and resident-mode bypass. They
validate record/u-area/credential and mode retention on refusal,
and correct mode1->mode0 and swap-block accounting on success.
All pass with the original source-extracted assembler leaf.

A second, independently compiled native fixture uses the EXACT
default-refusing JRST instruction from `proc_swap_entry_v481.s`:
without a selected MRES, disk mode1 MUST be refused without losing
the record, while a valid mode0 record still detaches. Two executed
unsafe mutations are detected by the native PDP-6 oracle:

* Replace the uninstalled-entry `JRST kret_neg1` by `kret_zero`,
  which illegally permits removal of an unowned disk allocation;
* Ignore the disk release leaf's still-mapped APR check, which
  illegally releases disk backing from a live image.

No mutant build failure, missing assertion, guest HALT or timeout
is counted as a successful mutant rejection. The original
`daimos-swap-detach-state-v880` and `daimos-vm-detach-order-v957`
host C tests retain common KCORE coverage with a dedicated
host-only disk service fixture; actual disk MRES code is covered
by this native test.

The companion `run-physical-v1666.sh` builds and boots a real
64K source-built PDP-6 GCC lowmem TSFS root with 3 DECtapes,
no attached DSK/DRM AUXST1, and optional PURE MRES enabled.
It expects octal fixed `__kcore_low_end=024076`, `PURE LOADED`
and `INIT V1`, and refuses premature SIMH exit/`?RT`/INIT
errors. The full auto-root KCC image builds separately and
contains both transient candidates, but only one is installed.

For exact A/B size acceptance, `run-size-v1666.sh` reads the actual
linked KCORE maps and MRES object sections from four independently
built images; it also verifies the terminal ownership symbols are
located in the appropriate fixed/MRES maps. Example:

    V1666_KCC_OLD=/path/to/v1665-kcc-auto \
      V1666_KCC_NEW=/path/to/v1666-kcc-auto \
      V1666_GCC_OLD=/path/to/v1665-gcc-lowmem \
      V1666_GCC_NEW=/path/to/v1666-gcc-lowmem \
      sh tests/validation/pure-terminal-backend-v1666/run-size-v1666.sh

Expected exact deltas versus v1665: KCC FULL fixed -114 words,
DISK MRES +42, PURE MRES +90 (net -72/-24); GCC lowmem fixed
-111, DISK MRES +42, PURE MRES +90 (net -69/-21). KCC transient
KINIT grows 44 words. This accounts for *installed* resident
MRES vs fixed KCORE separately; it does not imply peak RAM falls.

v1666 is a terminal memory-backend split, NOT activation of
compressed mode3. Permanent KCORE shrinks compared with v1665;
installed MRES grows by the backend-specific owner code. The
bitmap FULL restore v1659..v1664 native suite remains isolated
and is separately rerun before release. No actual guest process
compression or complete peak-RAM acceptance is claimed.
