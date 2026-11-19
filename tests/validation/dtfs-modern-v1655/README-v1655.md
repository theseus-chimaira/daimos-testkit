# v1655: current-source PDP-6 DTFS recovery and owner regression

Date: 2026-11-17. Current original linked PDP-6 DTFS
MRES-source native tests PASS. No production kernel/MM/FS
code changes or resident memory increase.

The historical v1518 and v1522 source-linked fixture
extractors are STALE: they predate the original v1561
pre-write provider/intent gate and the later v1572
operator-trust RW/CLEAN mount policy. Their old
source-string assertions no longer match the actual
runtime. A stale fixture does not prove a kernel failure,
and its old historical PASS must not be counted as
fresh original-source KCORE freeze evidence.

v1655 repairs the existing v1556 testkit oracle to
match the accepted original v1572 semantics, without
patching production: clean V2 can be admitted as RW
before its first DIRTY arm; a different mid-read
RW policy is no longer automatically rejected.
A NEW original native case tests that an armed
DIRTY V2 mount cannot recover under RO policy.
The historical obsolete RO-only source mutation is
replaced with an executed mutation ignoring ARMED
while preserving the same fail-closed safety property.
The source-linked 30-case original native PDP-6
V1/V2 read-fault test passes all 14 unsafe mutants.

The current full matrix independently runs:

| Exact current-source regression | Cases | Source mutants |
| --- | ---: | ---: |
| v1556 V1/V2 RBN0 read-fault return | 30 | 14 |
| v1554 physical DIRTY identity verification | 17 | 10 |
| v1561 actual mounted intent MM/owner gate | 35 | 13 |
| v1575 original poisoned-owner drain | Original leaf | 2 |

Total 82 enumerated native recovery/provider cases
and 39 separately executing source mutants, all
required to run to completion and be rejected where
unsafe. Source-linked high/low volume ID comparisons,
physical RBN0, shared BCACHE workspace invalidation,
WRITE_UNCERTAIN, RO/ARMED policy, stable mounted identity
and post-I/O gate are exercised by original instructions.

Run with original DAIMOS source:

    export TMPDIR=$HOME/tmp
    export PDP10_PREFIX=$HOME/cross
    export DAIMOS_REPO=/path/to/DAIMOS
    sh tests/validation/dtfs-modern-v1655/run-v1655.sh

This is a current-source matrix that substantially
replaces the historical v1518/v1522 coverage. It does
NOT independently re-execute their full old raw DTC
read/write identity and directory-cache integration
fixture, so those two stale extractors must remain
marked non-passing until separately modernized or
their exact coverage is demonstrated by physical
or newer native integration runs. No unrestricted
physical reel-exchange safety claim is made; v1575's
trusted-operator policy remains in force.
