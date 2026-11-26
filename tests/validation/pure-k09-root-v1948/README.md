# K09 v1948: FULL boot prefix and live root service selection

The root runner boots the same 256K KCC FULL AUTO RAW image via PTR
for all cases. Only disposable media copies are attached. The
explicit tape case changes the actual root selector to 2; it is a
diagnostic comparison, not a replacement for the AUTO case.

Supply fresh build directories via V1948_AUTO_BUILD (ROOT=auto,
BOOT=ptr, BOOT_PROFILE=full, COMPILER=kcc, PURE enabled),
V1948_TAPE_BUILD (ROOT=tape, TSFS_ROOT_MEMBERS=3),
and V1948_DRUM_BUILD (ROOT=drum). Set V1948_WORK to a new evidence
directory. Run make test-pure-k09-root-v1948. The default suite
includes the currently failing AUTO/DSK case and must report failure
until that defect is fixed. The runner stops at the actual INIT V1
console witness, examines live KCORE provider/service words, checks
all trampoline targets against the linked MRES maps, and checks
backstore capacity and initial allocation state. This is boot
selection acceptance, not an active swap workload.

The separate prefix verifier checks fresh build directories against
all three permitted resident package combinations, including the
maximum MM descriptor table. Run make test-pure-k09-prefix-v1948,
or pass several fresh directories to verify-prefix-v1948.py. Do not
use stale build directories containing unrelated package objects.

Actual v1948 evidence (paths relative to TMPDIR):

* k09-build-v1948.u9bvv8: original FULL OFF/RAW builds; original
  AUTO PTR image.
* k09-root-physical-v1948.29UinH/tape-noaux: actual original DTFS
  install failure, HALT 077016.
* k09-dtfs-fail-v1948.L8Hmrr: original physical KINIT/MM/package
  inspection. Free low interval [047615,055172), DTFS needs 005654
  words, required end 055471; shortfall 0277 octal (191 decimal).
* k09-fixed-v1948.qV1Vkz: corrected FULL RAW and OFF images.
  RAW prefix end 057445, padding 1195 decimal words. OFF prefix
  055172, zero padding. KCORE, PURE and SWAP binaries unchanged
  relative to original RAW build.
* k09-root-fixed-v1948.82BxG9: disk/drum, noaux TSFS, positive DRM
  AUXSTORE PASS. The initial DSK fixture had incorrect capacity;
  do not use it for DSK acceptance.
* k09-dsk-full-v1948.HpBiF7: full 0130000-sector DSK0, validated
  AUXSTORE 01000 backing blocks. Explicit TSFS selects SWAP;
  AUTO selects PURE and zero backing blocks instead. Other DSK
  units are absent. Both reach INIT; AUTO is a real selection
  failure, not a boot timeout. The root-probe/controller failure
  path requires investigation; no controller fix is claimed.

Prefix verifier: corrected FULL RAW/OFF and 64K GENERAL/STRICT
PASS, original FULL RAW rejected. Actual root trace oracle also
rejects the AUTO/DSK failure and altered missing INIT, duplicate
snapshot, and missing PURE witnesses. Altered transcripts are
oracle tests, not additional simulator executions.
