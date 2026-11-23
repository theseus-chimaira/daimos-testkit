# K05 v1902: bounded dual-owner FULL rollback (native component stage)

**Scoped original 48K physical PASS (2026-11-23).** The PDP-6 KCC
native component fixture and TWO independent original source-built
48K physical traces pass. The second trace proves autonomous slot-0
rollback and the subsequent new original FULL retry. It does **not**
yet establish the final successful FULL commit, user TERM/EXIT or
parent WAIT/HALT.
K05 remains OPEN; PURE/mode3 remain OFF by default.

## Scope

The source-backed v1901 full-system trace proves a real native
PACKED source `mm_free` refusal leaves a TRANSITION-held slot3
with original RAW source and complete provisional PROCESS target.
The v1902 candidate adds a slot-0 idle maintenance entry, sharing
the existing retry backoff and the non-FINALIZE swap retry tag.
The MRES verifies exact original MM ownership before freeing only
the provisional PROCESS target. It rechecks the MM table after
native free, including when a successful deletion has a lost reply.
The original PACKED source and the saved private executive context
must remain untouched. The TRANSITION bit is cleared only after
an exact sole unpinned PACKED source has been proved.

## Executed native tests

The fixture links original PDP-6 KCC service, restore, MM rebase,
MM expand and storage runtime with controlled test-only native MM
refusal and false-return cases. The test verifies:

- source pin1: repeated retries retain both extents and TRANSITION;
- target pin1: no target free while pinned;
- both unpinned: exactly one native target free and sole RAW owner;
- native target free -5: quarantine until a later genuine success;
- lost target-free reply: post-free exact owner scan recovers safely;
- duplicate, invalid-sized and MM-capacity mismatch: fail closed;
- foreign target-like PROCESS owner: never freed by the original
  slot3 rollback; original source remains intact;
- original saved PC/FDCTL, backing identity and private u-area
  preserved through all tested operations;
- no repeat free after TRANSITION clears, PI disable/restore balanced.

Run from `daimos-testkit`:

    export TMPDIR=${TMPDIR:-$HOME/tmp}
    export PDP10_PREFIX=$HOME/cross
    export DAIMOS_REPO=$HOME/git/DAIMOS
    make test-pure-k05-reconcile-native-v1902

The test reuses the independently source-built v1612 native baseline
unless `V1902_NATIVE_BASE` names an existing accepted baseline.
The actual native test evidence is under a versioned
`$TMPDIR/daimos-k05-reconcile-v1902-native.*` directory.

## Original full-system 48K physical evidence

Source-built original fixed KCORE SHA256:
`aa80ea2d98778298c13ae96de76c52815cfd40ad5486030e5056b436f85072f5`.
Optional PURE MRES SHA256:
`2dd7b7f7340d5b1b9542a97d0e8aca8478ac32afc3c555f0ae1ab38d0cd39a6b`.
Original fixed KCORE DXR IMAGE grows `024147` to `024165`
octal (**14 words**) with BSS unchanged at `000415` octal;
no additional per-process or MM allocation is introduced.
Optional PURE MRES IMAGE grows `004131` to `004615` octal.

The original installed PURE base is physically observed as
`032435` octal. The actual source-linked native FULL loader is
`036704`, source PACKED `mm_free` call `036012`, return
`036013`, original MRES service return `033556`.
At `036012`, the physical controller deposits only a test-only
source MM pin into original descriptor `024721`, changing
`000004000003` to `000014000003`. The real original
`mm_free(PACKED)` returns `777777777773` (-5), and slot3
remains TRANSITION, VMbase0, with MM count `022` octal (18).
The parent emits an original postfault `HB` while that pin
is still held. Only then does the controller release the same
external test pin, leaving the actual kernel to perform ALL
subsequent MM operations and process-state transitions.

The accepted second trace independently examines the relocated
original process table at physical `045516` octal:

| Physical stage | MM count | Slot3 metadata | Source descriptor |
|---|---|---|---|
| Native refusal and held-pin parent HB | 18 | `046635600401` | `000014000003` |
| First parent HB after pin release | 17 | `046635400401` | `000004000003` |
| Next parent HB / new FULL retry | 18 | `046635600401` | `000004000003` |

This proves the original idle service removes the provisional
PROCESS extent (MM18 -> MM17), clears the original slot3
TRANSITION bit and retains its **same** u-area `046635`,
VMbase0 and authoritative PACKED source. The original scheduler
then re-enters a new FULL restore (TRANSITION set again,
MM17 -> MM18). The parent remains independently runnable.
It is **not** evidence that the second FULL attempt has already
committed; final child EXIT and parent WAIT/HALT remain OPEN.

The first physical exploratory trace SHA256:
`a990a7ca815fce6b06d0749fba5b6112fe8093346caaacce9800f68c8150ea67`.
Accepted full process-table physical trace SHA256:
`3bb07f4c9a3429601dd63a3dce4832913e80fac0168fbf8a5d1fd786cb404ede`.
Twelve independently corrupted actual physical refusal/pin/
MM/TRANSITION/u-area transcript controls are all rejected.

The stronger source-linked native target-free controller also
passes on TWO independently source-built identical-production
48K PDP-6 guests. It breaks at actual original
`mm_free(PROCESS)` call `033245`, return `033246` (MM_OK=0),
and compiled transition-clear store `033275`. It proves the
original slot-0 idle reaper truly removed the provisional
target, preserved the exact original saved executive CTX_PC,
FDCTL and backing, and advanced the independent parent's
PCLK/HB. First strong trace SHA256:
`88e640e3eef12834a2fb6c97d3f0694280092844019c5372e35748a26fab25d5`.
Independent repeat SHA256:
`4fa67d715017fc4e566781c624c3041cf706129a1097fa35216856e1ce5f19fb`.
SIX additional independently corrupted original native-target
physical controls all reject, **18 total v1902 physical
negative controls**. The original terminal FINALIZE/WAIT
path remains outside this scoped acceptance.

Reproduce the accepted source-built physical test (after
building the 48K source-linked guest and its original installed
MRES base probe):

    export V1902_BUILD=$TMPDIR/pure-brk-pressure-v1614.8oeD73/build
    export V1902_PROBE=$TMPDIR/daimos-k05-reconcile-v1902-probe/probe.clean
    export V1902_PHYSICAL_WORK=$TMPDIR/daimos-k05-reconcile-v1902-physical-v2
    make test-pure-k05-reconcile-physical-v1902
    make test-pure-k05-reconcile-audit-v1902

The independent exact native target-free/CTX proof can be
replayed from its source-built evidence:

    export V1902_COMMIT_WORK=$TMPDIR/daimos-k05-reconcile-commit-v1902-physical
    make test-pure-k05-reconcile-commit-physical-v1902
    make test-pure-k05-reconcile-commit-audit-v1902

The physical preparation derives all newly linked KCORE/PURE
entry points from the actual DXR/map and the original FULL
MM-free relocation. The process-table locator for the second
trace is derived from the first real guest snapshot, never
from the older v1901 address.
