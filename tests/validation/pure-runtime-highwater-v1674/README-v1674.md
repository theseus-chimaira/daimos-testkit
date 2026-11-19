# v1674 physical PDP-6 runtime MM write-watch high-water

**Status: PASS for the bounded 48K PDP-6 post-user RAW PURE committed-MM
high-water workload (2026-11-19).** This testkit-only extension follows
the accepted v1673 RAW PURE pressure gate. Scope is original physical
MM descriptor changes, not every possible scheduler schedule or a
process-instruction trace. The PURE development branch is unmerged.

## 2026-11-19 paired physical write-watch acceptance (PASS)

The corrected, unmodified original PDP-6 physical console captures
completed in **both** 48K GENERAL and STRICT swapless configurations.
Both used the same source-built KCORE (`66296e13440e1f4db3bf263e181dc33e085f55dc4b0f07c09f147e6c1c88b506`
SHA256) and PURE MRES (`834a99cc9d11668e761f679c7bf500be7aeff5d1db1216540edae9996ea27e49`
SHA256), the identical deterministic pipe-held test PID1 and nine
children, isolated three-member TSFS roots and no attached DSK/DRM
swap media. Mode3 bitmap compression was OFF.

| Source-linked physical MM observation | GENERAL | STRICT |
| --- | ---: | ---: |
| Before A free / largest extent | 27339 / 27339 | 27339 / 27339 |
| Pressure B free / largest extent | 2692 / 1539 | 2692 / 1539 |
| After nine EXIT/WAIT, C free / largest | 27339 / 27339 | 27339 / 27339 |
| Minimum free at committed MM write | **1255** | **1255** |
| Maximum physically nonfree (of 49152) | **47897** | **47897** |
| Physical MM write-watch events A-to-C | 3122 | 3122 |
| MM count commits | 194 | 194 |
| In-place BRK size changes | 5 | 5 |
| In-place PURE drop / restore span changes | 9 / 9 | 9 / 9 |
| Other replayed descriptor writes | 2905 | 2905 |

Both completed original v1673 physical-state verifiers PASS, including
nine packed RAW owners and native SYS_MEMINFO, and the tenth native
RUN refuses at pressure. Both complete original v1674 physical
write-watch replays PASS: 1660 A-to-B writes (121 count commits,
5 BRK and 9 PURE span changes) and 1462 B-to-C writes (73 count
commits, 9 PURE restorations). Every watched physical MM word after
replay exactly equals the independently examined B/C snapshot. The
active original MM extent/owner table, process records and free ranges
return to their original A values after WAIT. Inactive descriptor slots
may retain old data after the count shrinks; they are not live owners.

Every original physical recording also passed **five executed negative
transcript mutations** (removed watchpoint, mutated count write,
missing write event, corrupted PURE span and corrupted BRK span) and
a separate forged high-water JSON rejection. The six independent
rejections are source-linked to the exact tested KCORE and console.
The original paired `compare-v1674.py` passed on the actual source-
matched general/strict outputs with byte-identical reports:

- High-water report SHA256:
  `088deea77704e6f5716045844013aea1a1fab7df3ecadf6e50880e46a7d00305`
- Original v1673 physical report SHA256:
  `29e052c9372d0175aab02f6b39587e40edfca3d1184499d12f08d0f4a5f87a88`

The high-water is **a committed physical-MM observation**, not an
instruction-bound latency or an unchanged-scheduler timing guarantee.
The more demanding RUN/EXIT/WAIT pattern remains real PDP-6 physical
execution, not an emulator of the MM allocator. This closes only the
specified 48K RAW-mode general/strict post-user high-water gate; no
production KCORE text/data was altered by v1674 instrumentation.

## Deterministic source-matched child fixture

The original v1673 sleeping child has a finite 600-second clock
interval. SIMH physical write watches change wall-clock scheduling,
so that child is not an adequate high-water stress fixture.

An initial v1674 pipe-based fixture also failed: its RUN FD map
reversed the child and parent descriptor operands and its child used
TTY-style SYS_READCHAR on the wrong descriptor. The genuine physical
console printed `V1673 UNEXPECTED TRIGGER ADMISSION` before HALT;
those results and the incomplete high-water minimum are **rejected**.
Do not classify this as a proven kernel defect or accept the earlier
1,362-word preliminary minimum as an end-to-end result.

The revised PID1 creates one ordinary native PIPE before checkpoint A
and passes the **parent reader as child FD0** through RUN FD mapping.
Each child blocks in native SYS_READ_WORDS; original kernel code drops
its user mapping before the wait, making it eligible for normal PURE
reclamation. PID1 retains the writer and, strictly after physical B,
writes one checked 36-bit release token per child. Each restored child
verifies both that token and its original PID-specific writable-suffix
canary before native EXIT. No timeout, debugger-specific guest hook or
kernel change controls child release. The PIPE object remains alive in
PID1 at A and C, preserving the expected baseline after WAIT.

## 2026-11-19 corrected-fixture physical control (general PASS)

The new v1674 C89 PID1 and 36-bit PIPE child were source-built with the
unmerged DAIMOS PURE development source. The uninstrumented 48K general
PDP-6 run completed all three original physical CTY checkpoints:

| State | Free MM | Largest gap | Packed RAW owners |
| --- | ---: | ---: | ---: |
| Before A | 27427 | 27427 | 0 |
| Pressure B | 2780 | 1627 | 9 |
| After WAIT C | 27427 | 27427 | 0 |

The original v1673 physical-state verifier PASSed; all nine owners had
exact 128-word RAW-suffix reclamation and resumed after the explicit
PIPE release. Native MEMINFO reported 5712 resident process words at
B. A separately executed v1673 native negative run on this exact
original physical console rejected five witness mutations plus a
forged summary. The physical console SHA256 is
`325949e838260231496c0acaffadf1b52b5acd8c1429f3ffe0b32529b2437314`;
the independently derived v1673 JSON SHA256 is
`de654d4ecac7b8971cf3927ed585582c4147203a1d0fae4d864b5f9402de6d97`.

This closes only the **corrected fixture's general-profile physical
control**, not v1674's write-watch high-water, general/strict paired
acceptance, PI6 fault pressure or production integration.

## Why a new measurement is needed

The v1673 CTY checkpoints A/B/C prove stable original physical MM state
before RUN, after nine owners are packed, and after EXIT/WAIT. They do
not observe allocation spikes between checkpoints. Sampling SIMH at user
virtual-PC addresses is unsafe because those addresses alias KCORE PCs.

This experiment uses SIMH **physical memory write** breakpoints (`-W`),
not execution breakpoints. The host arms watches after PID1 pauses at A
on the original `mm_extent_count`, all 64 original MM extent-descriptor
words for the 48K capacity of 32, and six fixed arena/core descriptor
words. Each modified physical address is recorded with its new value.
All 71 watches are verified with `show -C -W break`. They are disarmed
while the guest holds at C. Neither the kernel nor the guest test
program has any new instrumentation.

`trace-v1674.py` starts with the physically read A descriptor table,
replays **every** watched store in source order, and requires the
reconstructed table to equal the independently examined original MM
at both B and C. Count writes are the atomic insert/delete commits;
they must always leave a valid extent table. In-place extent size edits
are source-qualified by the original typed MM shrink/grow ranges and
by the distinct PURE MRES rebase/claim/release span writers. They are
likewise validated as commits; a PURE prefix claim can temporarily
increase RAM use without changing the extent count. Every other descriptor write
(generic table shift or metadata update) is replayed but NOT counted as an allocation
sample, even when a partly shifted table happens to look geometrically
valid. This avoids reporting a non-committed intermediate copy as a
real memory high-water.

This establishes high-water among the captured valid MM states after
every original physical descriptor write, not the transient consumption
of an allocator's CPU registers or a non-MM subsystem. In particular,
SIMH stop-and-examine affects host elapsed time and can perturb the
scheduler/PCLK interleaving compared with an uninstrumented run. This
is **not** a performance benchmark, a timing-neutral experiment, or an
instruction-by-instruction execution trace. Acceptance establishes a
measured event-commit peak for the explicitly observed physical run,
not a theorem about all possible future process schedules.

## Execute

    DAIMOS_REPO=/path/to/DAIMOS-development \
      make test-pure-runtime-highwater-v1674

The source is the unmerged PURE development branch with mode3 off.
The v1673 runner builds isolated three-member TSFS test media and
executes the original general+strict 48K nine-child pressure test,
including its accepted negative checks. The v1674 runner substitutes
only its SIMH host controller, then replays each source-linked console,
compares the two high-water reports and executes five original-physical negative mutations (missing watch
registration, corrupted original count-write value, missing actual MM
write event, damaged PURE MRES span, damaged BRK span) plus a separately
forged peak summary. The two span mutants are selected using the
original linked KCORE symbol map and real committed write PCs.

For debugging only, set `V1674_ONLY_VARIANT=general` or `strict` and
`V1673_ONLY_VARIANT` to the same selection. Existing source-built
v1673 images may be reused through `V1673_FIXTURE_BUILD`,
`V1673_GENERAL_BUILD` and `V1673_STRICT_BUILD`, but the original root
manifest must match the supplied fixture path. This diagnostic option
skips the paired profile comparison and **does not close acceptance**.
Set `KEEP_TEST=1` to retain disposable evidence. `V1673_TIMEOUT` is
the host wall-time timeout per physical CTY checkpoint, with v1674
defaulting to 3600 seconds to accommodate instruction-level debugger
stops. This cannot make a failed guest pass: the physical v1673 and
v1674 oracles still require every expected lifecycle, owner and
memory checkpoint, and the child is released by a pipe event rather
than by a timer.

## Rejected first instrumented trial: duplicate A monitor word

The first complete 48K general write-watch run reached nine-child
reclamation, PIPE release, EXIT/WAIT and the guest PASS marker, but the
v1673 physical transcript verifier rejected the A checkpoint with
`duplicate physical MM word 23416`. The v1674 host controller had
issued a second EX of the already observed `mm_extent_capacity` when
arming the 71 -W watches. The physical console is retained as a
**rejected diagnostic**, not an accepted v1674 result. The controller
now reads that capacity once from the original first A snapshot and
never re-examines it. A fast native source/monitor regression asserts
that duplicate-read error cannot silently recur. Both physical profiles
are rerun under the same fixed p10fold toolchain; the old mixed-tool
run is not eligible for paired acceptance.

The actual logged write stream exposed three distinct legitimate span
mutations: five in-place `vm_space_brk_current` growth commits in fixed
KCORE, nine PURE MRES 128-word suffix rebase commits and nine PURE MRES
128-word prefix restoration commits. The v1674 oracle now classifies
these separately, validates exact span deltas/ends, and requires 5/9/9
per original A-to-B/B-to-C intervals. Ordinary MM descriptor shifts
remain excluded from committed high-water even when transiently valid.

## Cross-profile build fingerprint gate

The first independent v1674 general/strict physical control runs passed
individually but were NOT comparable: their KCORE executables and all
PURE MRES DOBJ inputs had identical SHA256 hashes, yet the general PURE
MRES contained two obsolete cross-object folds (103+25 donor words) and
was 88 words smaller at runtime. `p10fold` was replaced between the
builds, at 10:54 CET on 2026-11-19. The newer tool includes commit
`01e58f21`, rejecting folds where numerically identical local relocation
offsets belong to different DOBJ objects. Rechecking both identical
input sets with the newer binary emits zero folds. The original general
physical free baseline was 27427, whereas strict was 27339; both
reclaimed 24647 process/MM words and returned to their own baseline.

This was a mixed-toolchain comparison, not evidence that strict swapless
requires extra resident RAM. The corrected requirement is to source-build
both variants using the same updated tools. The v1674 paired comparison
now also requires a byte-identical linked `pure-mres-v1612.dxr` SHA256,
in addition to matching fixed KCORE, test fixture and physical checkpoints.
A read of the *current* installed tool's hash alone would not prove the
version that produced an earlier image, hence the linked output hash is
the actual identity gate.

## Gates not covered

The accepted post-user event-commit high-water is bounded to the
original MM descriptors and this source-matched 48K TSFS/PURE workload.
It does not prove non-MM temporary CPU-register use or all possible
scheduler interleavings. Independent gates remain for ROOT=auto,
DSK/DRM and KCC full-profile regression, PI6 fault injection,
compressed bitmap mode3, KA10 and full 32K boot.

The fast `make test-pure-runtime-highwater-native-v1674` target exercises
the replay classifier with synthetic descriptor writes: a geometrically
valid but uncommitted intermediate shift must not be counted as an MM
high-water; a subsequent count commit and an in-place resize must be
counted. Unknown physical watch addresses and unpaired breakpoint
headers must fail. These native checks do not replace the real physical
test and are never called physical acceptance evidence.

## Deterministic event-blocked children (v1674 correction)

A first exploratory write-watch run of the original v1673 timer-sleep
fixture was **not accepted**: the tenth pressure RUN unexpectedly
succeeded after enough 600-second physical PCLK time elapsed during
slow SIMH monitor instrumentation. This is a workload synchronization
failure and not evidence of a kernel memory regression. Longer timer
sleep values alone do not correct this test-design flaw.

The v1674-only fixture now gives each child an inherited PIPE reader
on fd0 and makes it block in the existing `SYS_READCHAR` syscall.
The original kernel pipe event wait sets `PROC_SLEEP`, so these are
normal reclaimable sleeping processes. PID1 keeps the shared writer
open and sends nine explicit 'R' release characters **after** the
physical B checkpoint. Each child verifies its writable PURE suffix
canary after restoration before EXIT(0). This bounds the experiment
by a logical event rather than host elapsed time or guest timer expiry.
The pipe and descriptors are allocated before baseline A and remain
live through C; the test still requires exact original MM restoration
relative to A. The C89 PID1 and target assembly child exist only in
the testkit. There are no new kernel hooks, timers or ABI changes.

## 2026-11-19 matched candidate binary pair (pre-acceptance)

The fixed-toolchain general and strict 48K source-built test candidates
use DAIMOS PURE branch `9d8f3646` and the same original v1674
pipe-controlled PID1/child fixtures on isolated three-member TSFS.
Both actual `kcore.dxr` binaries have SHA256
`66296e13440e1f4db3bf263e181dc33e085f55dc4b0f07c09f147e6c1c88b506`.
Both original `pure-mres-v1612.dxr` binaries have SHA256
`834a99cc9d11668e761f679c7bf500be7aeff5d1db1216540edae9996ea27e49`.
The `kcore.map` and `pure-mres-v1612.map` hashes also match across
profiles. This isolates the strict KINIT's omission of the DISK SWAP
MRES while keeping original KCORE and PURE runtime code bit-identical.
The prior mixed-toolchain candidate had a different PURE MRES, and
**cannot** be included in a paired accepted comparison. This is an
accepted *build-identity preflight only*; it does not establish the
continuous post-user physical high-water.
