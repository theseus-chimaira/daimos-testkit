# v1665 KINIT root-aware exclusive SWAP/PURE MRES selection

The source-linked v1665 tests use the **actual**
`proc_swap_minit_v481` source extracted from DAIMOS
`system/kernel/modules/module_minit.c`. They compile it as strict
host C89 with isolated hardware discovery and MRES installer
fixtures; no memory-management algorithm is replaced.

Run:

    DAIMOS_REPO=/path/to/DAIMOS TMPDIR=$HOME/tmp \
      sh tests/validation/pure-boot-select-v1665/run-v1665.sh

The six C89 source configurations are: D6FS/tape/PURE on;
tape-only/PURE on; disk-only/PURE on; and the corresponding PURE-off
configurations. Each tests selected-root class AUTO, DTC, DSK, DRM,
the absence of an AUXST1 descriptor, a zero BACKSTORE descriptor,
a positive validated BACKSTORE and a failed discovery with stale
nonzero capacity. It checks exact installed MRES, zero/valid disk
exports, two-entry PURE scheduler trampoline patching, seven-entry
disk patching, no premature diagnostic and no unselected install.

The runner also parses the genuine `module_table.s`: physical
driver MINITs must precede root selection; root selection must
precede SWAP MINIT; AUXSTORE post-MINIT comes afterward. A distinct
unsafe mutation swapping ROOT and SWAP order is rejected. A second
independently compiled unsafe mutation changes DTC selection to
non-DTC; the actual selector oracle rejects the resulting wrong
installation. The historical v1613 source-linked selection suite,
including its absent-AUXST1 mutation, is also rerun.

The **actual** top-level PDP-6 Makefile's `MRES_PACKAGE_OBJS`
is evaluated, not guessed, for ROOT=auto/tape/disk/drum with PURE
enabled and auto/tape with PURE disabled. The PURE candidate must
be linked only when a DTC root is supported and PURE explicitly
enabled. The old disk candidate stays linked in all supported
multi-backend configurations. On boot, `mres_install` relocates
only the selected candidate into permanent KCORE-adjacent memory.

This suite proves KINIT selection policy and candidate-link
constraints; it is not proof of a successful source-built boot or
compressed mode3 lifecycle. The full-image build and physical
guest checks are separate. Permanent KCORE remains unchanged;
mode3 admission remains disabled and PURE defaults OFF.

The companion `run-physical-v1665.sh` boots an actual 64K source-
built PDP-6 with three-member TSFS root, no attached DSK/DRM
BACKSTORE, and PURE enabled. A KINIT image built from v1665 is
required; the script optionally reuses an existing build via
`PURE_BOOT_BUILD_V1665`. It checks `MEM 64 K`, `DTC OK`, `PURE
LOADED`, `INIT V1` and no `?RT`/INIT failure, with an explicit
controlled simulator timeout. The current v1664-based GCC lowmem
fixed bound is octal `024255`. The original v1613 smoke script
expects octal `024254` and aborts before SIMH on the newer code;
this new versioned script is the release acceptance for v1665.

The full KCC ROOT=auto PURE-enabled image separately links both
transient swap candidates and reports octal `__kcore_low_end=
024535`, `__kinit_image_end=140154`. Auto-root physical selection
and positive-BACKSTORE physical fallback are not yet claimed.
