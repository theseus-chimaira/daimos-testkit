# v1659 bounded, disjoint PURE bitmap probe (native PDP-6)

Base: committed v1658 DAIMOS `435557a54761d5910f435752c3a03c84afb1bef4`.
This is **not** mode3 compressed-process support, a production swap
replacement, or a 48K/64K physical RAM-saving result.

## Why the first transaction must stay unpublished

Existing KCORE accepts only storage states 0=RESIDENT, 1=DISK,
2=RAW PACKED. `proc_storage_expect_v30` and `proc_storage_publish_v30`
reject state 3; terminal `pdp6_pure_detach_v1609` expects EXACT RAW
suffix length. Publishing a 161-word bitmap as a 3,456-word RAW
PACKED owner would make EXIT/WAIT and restore invalid. Do not change
permanent KCORE for an unproven compressed owner.

## Original opt-in source-linked native prototype

`proc_pure_bitmap_probe_v1659` requires an existing held TRANSITION,
verified PURE backing, an exact unpinned RAW PACKED_PROCESS owner,
and exclusive process lifecycle. It pins the RAW source, counts every
nonzero original word and computes `ceil(raw / 36) + nonzero`. When
this count cannot shrink, it performs no allocation. Otherwise it
allocates a second, exactly sized disjoint PACKED_PROCESS extent via
`mm_alloc_aligned_noreclaim` (no eviction recursion), pins it, invokes
the original 30-word v1451 bitmap encoder and independently verifies
each decoded value and exact final encoded length without a second
RAW-size decode allocation. A final partial mask must have no unused
presence bits. It then unpins and frees the provisional destination,
unpins the source, verifies the original single RAW owner and returns
only the measured compressed size; no process/MM state is published.

On any refused target unpin/free or source unpin, the caller keeps
TRANSITION held. The probe never assumes a failed MM call did not
mutate anything, performs no forced release and never exposes a
potential duplicate owner to the scheduler. The source is untouched.

## Native tests

```
export TMPDIR="$HOME/tmp"
export PDP10_PREFIX="$HOME/cross"
export DAIMOS_REPO=/path/to/DAIMOS-v1659
sh tests/validation/pure-bitmap-probe-v1659/run-v1659.sh
```

The runner first executes the original v1658 PURE/FULL/owner suite,
then compiles the new real C source with KCC and links the production
v1451-identical assembly on the PDP-6 model. The MM allocator,
provider and injected failures are controlled native fixtures; they
are NOT claimed to be the installed physical MM allocator.

The twelve bitmap-probe native checks cover successful exact sizing and cleanup,
allocation NOMEM, destination pin refusal, destination unpin refusal,
destination free refusal, RAW unpin refusal, corrupted literal,
full-density no-gain refusal, illegal last partial mask, overlapping
allocator geometry, duplicate RAW owner, and the v1657 geometry
3,456 RAW/65 literal/96 masks = exactly 161 bitmap words.
Failure cases check unchanged RAW words, process backing, mode,
TRANSITION, exact MM descriptor counts and pins.

The independent real-MM native case extracts the UNMODIFIED current
`mm_pdp6.s` allocator, extent-insertion, pin, unpin and free leaves.
It constructs a 3,456-word pinned RAW extent with exactly 883 words
remaining in its managed arena. The real no-reclaim allocator must
reserve a 161-word, alignment-one PACKED_PROCESS destination at the
correct high base, pin/unpin and free it, leaving the exact original
source. It must independently distinguish 884-word NOMEM, descriptor
exhaustion, reserved types 5/7, invalid types 0/8/-1, without mutation.

This extra test caught an actual permanent KCORE defect: prior MM
assembly rejected declared `MM_TYPE_PACKED_PROCESS=4` even when free
space was sufficient. The corrected type check accepts precisely
1..4, preserving all invalid-type exclusions. The test also assembles
and executes two deliberately broken variants of the production MM
leaves: the historical type1..3 guard and an overbroad type1..7 guard.
Both are rejected by the original positive/negative MM oracle.
Existing real-MM v1111 shortage classification and v1552 pinned
allocation/cleanup regressions still pass.

A separate test-only source mutant removes the entire bitmap stream
verification from the compiled original C transaction. Its corrupted
literal case MUST execute and fail the native oracle (octal 001604),
not just fail link or compilation. The unchanged v1451 codec is
compared instruction-for-instruction before compiling the new probe.

The standalone measured current probe object is 586 PDP-6 TEXT words
with zero DATA/BSS; the codec is 30 TEXT words with zero DATA/BSS.
These are test-only code costs, not measured installed MRES or KINIT
staging. The large C probe must be considered in net RAM budgeting.
In contrast, the corrected MM type guard is installed in permanent
KCORE and grows its linked low-end boundary by two words in the fresh
48K source build (`024253` to `024255` octal); its KINIT staging end
likewise moves `113641` to `113643`. That newly source-built 48K
GCC selected TSFS-root plus secondary-DTC3 original six-child guest
now PASSes PIPE/WAIT/EXIT and normal HALT PC000000. KCORE stream
SHA256 is
0a547e28dd9223e1a26420e4a75f8a6a5ca39836dd62b6a3c3d531ced57fc8f8.
The physical guest exercises the allocator correction as part of
the original boot, but does not execute v1659 bitmap compression.

## Next stage, not implemented by this gate

Implement a separately recoverable compressed owner with validated
mode3, encode/commit rollback, bounded FULL decode, terminal EXIT/WAIT
release, failed-unpin quarantine and real 48K/64K physical MM/PI6
tests. Compare matching complete system high-water and continuous
peak with RAW and PURE-OFF. Until that proof passes, production RAW
remains authoritative and mode3 MUST NOT be enabled.
