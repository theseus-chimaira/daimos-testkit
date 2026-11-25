# K05 v1900: terminal cleanup of original RAW+PROCESS dual MM ownership

**Historical gate:** v1920 supersedes the v1900 terminal policy. The
v1900 direct dual-owner acceptance fixtures require a matching historical
DAIMOS checkout (for example db2a59b2); they intentionally do not pass
against v1920. Current source must reconcile uncertain FULL owners in
the idle service before terminal release. Use
`test-pure-terminal-identity-v1920` and
`test-pure-terminal-finalizer-v1920` for the new contract. The earlier
physical evidence remains historical evidence, not current acceptance.

Date: 2026-11-23. Source-linked **native PDP-6 acceptance PASS**;
the existing original terminal single-PACKED path rejected an
otherwise legitimate FULL rollback state with exact PACKED RAW
and a separate complete temporary PROCESS target, both slot-owned.
The original native guest reproduced this bug with exit status
`000000001001` octal before the production fix. The corrected
original terminal, original VM destroy ASM, KCORE swap-detach C,
and actual storage-mode assembler now pass the expanded native
guest, historical v1609/v1680/v1681 regressions and four
independently executed unsafe original-ASM mutants.

## Production correction and memory

The opt-in PURE terminal MRES export now uses existing ACs and
the original private stack, without new process fields, MM table
descriptors or BSS. It disables PI during the short exact MM
owner scan, subsequent native frees and result publication.
Preflight still verifies PACKED mode, TRANSITION, u-area, saved
immutable backing identity, absent runnable VM and APR geometry.
It bounds the live MM extent count by both the permanent 136
descriptor maximum and runtime `mm_extent_capacity`, then checks
that this slot owns EXACTLY one unpinned RAW PACKED suffix with
its computed original writable-suffix size, plus optionally ONE
unpinned complete aligned PROCESS target with original APR size.
Unknown, malformed, duplicate, extra, pinned or incomplete
process-owned descriptors fail closed before either free.

The exact unpinned provisional target is released FIRST. A
definite native MM refusal leaves the RAW untouched. If the
target physically freed despite a false error reply, the next
existing PREVM retry finds sole RAW and completes safely.
The authoritative source is released only after target success.
If the source free returns failure, a PI-excluded scan validates
that the source base and ALL slot-owned PROCESS/PACKED descriptors
are actually gone before publishing RESIDENT. A refusal or
foreign/reused source base retains the original PACKED mode for
existing idle-stack PREVM retry and exponential backoff.

Original fixed KCORE remains byte-identical at SHA256:
`33bf700218a73fefcb36ebb1f1d835c1817f3a291a642898ccb3cbd5d9039d8b`.
Earlier optional PURE MRES SHA256:
`a0fb25c51cf1c57f4bc70ca1dc83d8b9ea39b1ac3ddb3bba7b9ffcea17e5b3fd`.
Fresh final source-built corrected PURE MRES SHA256:
`09bcb71e4cbb172222f6389153c27293353fdaf6d3210eeef4630ed06de934f2`.
Original 17056-byte DXR, corrected 17600-byte DXR: +544
bytes on disk. `dxrcheck` confirms original installed PURE image
`004027` octal words, corrected `004131` octal words: **+000102
octal = +66 decimal actual installed 36-bit words**. The other
two DXR words are the larger relocation map (`000072` ->
`000074` octal). Zero KCORE words, BSS words, process/MM format
fields or fixed lowcore.
The original linked terminal MRES entry remains at `003675`
octal. Both original and current-source MRES images are built
with the same 48K original PDP-6 configuration.

## Executed original native tests

`run-native-v1900.sh` compiles and runs the original production
terminal assembler, `vm_pdp6.s` VM destroy, KCC-produced
`vm_pdp6_swap.c` and storage-mode assembler on the real PDP-6
instruction simulator. The explicit testkit-only MM stub extends
the historical v1609 allocator fixture to permit and observe
an exact PROCESS free and separate false success replies. The
production allocator implementation is not replaced in any
source-built 48K boot image.

Native cases cover exact two-owner release, subsequent idempotent
VM destroy, repeated held RAW and held target pin refusals then
real release, wrong target geometry, extra target owner, foreign
PROCESS at the target base, invalid reserved owner type, out-of-
capacity MM count, genuine target free refusal, genuine RAW free
refusal, a committed target deletion with lost reply followed by
normal retry, and a committed RAW deletion with lost reply
reconciled against the physical MM table.

Four different test-only mutations of actual production ASM are
compiled and executed against the same native guest, with exact
expected nonzero assertion exits:

| Executed unsafe change | Expected native exit (octal) |
|---|---|
| Ignore authoritative RAW pin | `000000001103` |
| Ignore provisional PROCESS pin | `000000001203` |
| Accept incorrect target extent size | `000000001305` |
| Publish after uncommitted source free | `000000001714` |

All four are rejected. Historical v1609 single-RAW terminal,
v1680 pinned/definite MM free refusal, and v1681 source-linked
FINALIZE+PREVM/backoff native tests pass, including their executed
historical unsafe mutants. Historical test-only mutation anchors
were updated to identify the new exact RAW guard and renamed
preflight refusal; production assertions were not weakened.

## Current-source 48K PDP-6 physical failure-and-progress audit

The `run-physical-v1900.sh` compatibility test uses a FRESH complete 48K
source-built KCORE, corrected optional PURE MRES and the accepted
testkit-only five-child RUN/BRK/PIPE pressure with independent
resident parent `HB`. It reuses the accepted original v1895
physical-source-free-refusal controller with source-linked current
PURE restore opcodes and derived installed MRES base. Both DSK
and DRM AUXSTORE attachments are excluded, exactly as in the
original v1614 no-AUXSTORE harness. Real TSFS/no-BACKSTORE
selection MUST show `PURE LOADED`. The versioned physical
preflight also checks the actual attached TSFS root tapes against
the compressed `/SYSTEM/COMP` test manifest: one intermediate
post-link image rebuild had regenerated the base tapes without
the compressed child and the original guest correctly emitted
`!3`. Restoring only the source-built test tapes corrected the
fixture. The kernel and newly linked PURE module were unchanged.

The enlarged PURE module moved the dynamically allocated process
table from original `044712` to `045014` octal. The physical
controller derives this from the ORIGINAL runtime pointer and
the linked PURE DXR image-word increase (`004027` -> `004131`),
then checks the NEW runtime pointer and reads the actual parent
and slot3 records at their real physical addresses. A stale
original `044712` dump is not accepted as the new process table.

The final current-source original 48K physical controller
physically injects a persistent extra PACKED-source pin at the
actual original `mm_free(PACKED)` call and verifies the genuine
native `MM_ERR_BUSY=-5` response, exact two-owner MM conservation,
slot3 TRANSITION/VM0, original TSFS ROOT and two independent new
parent user `HB`s with real advancing fixed-KCORE PCLK. The
same read-only source-linked original v1895 owner oracle and
ten executed unsafe transcript mutants are reused against the
exact newly built v1900 PURE SHA256; they reject unsafe owner,
pin, process and heartbeat changes at the original checkpoints.

**Final original PDP-6 physical run PASS:** 48K, actual original
native PACKED-source free `035310` refuses with real AC1=-5,
exact MM18 owners retained, slot3 TRANSITION/VMbase0 at the
newly derived process table `045014`; parent slot1 makes two
autonomous original user HBs, PCLK `021574` -> `021674` octal.
The independent v1900 oracle and TEN executed unsafe physical
transcript controls PASS. Accepted normalized physical SHA256:
`91d9cacd28c8f6de77640340f30a431e6e74f23959eabc411fcdcc033aa45a55`.
All v1893-v1899 seven-case historical physical audits and 74
executed negative controls were also re-run and PASS.

**This does NOT directly force a quarantined dual-owner slot
through a real hardware user SIGTERM/idle-finalizer retry.** Such
a full 48K foreign-termination and eventual pin-release experiment
remains the next distinct physical acceptance gate. The new
dual-owner finalizer was separately exercised with original
PDP-6 native MM and source-linked FINALIZE/PREVM instructions.

## Reproduction

    export TMPDIR=${TMPDIR:-$HOME/tmp}
    export PDP10_PREFIX=$HOME/cross
    export DAIMOS_REPO=$HOME/git/DAIMOS
    make test-pure-k05-terminal-dual-owner-native-v1900
    make test-pure-k05-terminal-dual-owner-finalizer-native-v1900

To source-build the full real 48K guest from current production
sources and the accepted parent-HB test fixture:

    export V1892_SOURCE_DIR=$TMPDIR/daimos-k05-terminal-dual-owner-source-v1900-final
    sh tests/validation/pure-k05-resident-peer-v1892/build-v1892.sh
    export V1900_BUILD=$TMPDIR/pure-brk-pressure-v1614.hWkYY8/build
    export V1900_PHYSICAL_WORK=$TMPDIR/daimos-k05-terminal-physical-v1900-real-v3
    export V1900_PROBE=$TMPDIR/daimos-k05-v1900-physical-probe/probe.clean
    export V1900_PRIOR=$TMPDIR/daimos-k05-persistent-source-pin-v1895-real
    make test-pure-k05-terminal-dual-owner-physical-v1900
    make test-pure-k05-terminal-dual-owner-physical-audit-v1900

If the boot image is relinked AFTER its original source-build,
restore only the TEST-ONLY compressed root media before running
the accepted controller, without changing production sources:

    sh tests/diagnostics/pure-full-restore-v1638/prepare-media-v1638.sh \
      "$TMPDIR/pure-brk-pressure-v1614.hWkYY8" \
      "$TMPDIR/pure-brk-pressure-v1614.hWkYY8/build"

The `V1900_BUILD` directory above is a recorded particular
source-built fixture, not a required permanent path; other fresh
versioned 48K build directories work with the same source and
control. v1900 does not enable RAW PURE or mode3 in default
production. K05 and K06-K09 remain open pending the actual
full-system quarantined owner terminal path and broader fault
and scheduler integration matrix.
