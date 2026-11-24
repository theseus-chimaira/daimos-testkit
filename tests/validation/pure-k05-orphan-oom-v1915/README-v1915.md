# K05 v1915: real requester-only capacity OOM beside foreign FULL child

Date: 2026-11-24. **Scoped original 48K PDP-6 physical PASS.**

## Scope and actual source

This exercise checks whether the original physical allocator may
reclaim an uncertain foreign-owned FULL target or the still-live
RAW source while a *different* user process requests an impossible
BRK allocation. After the requester dies of ordinary native OOM,
the remaining healthy peers EXIT and the original quarantined
child becomes the sole live user. This is a two-stage ordering:
the OOM request occurs **while the parent is still live**, not
after the last foreign orphan has become the only live process.

The test uses a newly source-built user guest with one extra
**test-only parent USER gate**; original KCORE/PURE sources and
DXR binary images are unchanged. The user guest first performs
the accepted v1907 genuine packed-source `mm_free=-5`, test-
only foreign owner2 PROCESS target, and a genuinely refused
parent TERM(3). Only then does the controller arm an existing
test USER gate. Parent user code emits `P` and executes an
actual `dsys_brk(0130000)` syscall. The requested USER APR is
within the legal logical BRK range but cannot fit any physical
48K managed arena, even if every other user extent were freed.
If the call ever returns, the guest invokes `p14_fail('O')`;
such a transcript is rejected.

The original `vm_space_brk_current` checks its requested
aligned APR with `mm_arena_fits_v1260` **BEFORE** attempting
the general `mm_alloc_aligned` allocator. Because no arena
can fit this request, the VM BRK path returns genuine
`MM_ERR_NOMEM=-1` without entering general compaction or
victim reclaim. The original requester-only fatal path
`proc_fatal_close_current_v879` then releases the parent.
This is specifically an early capacity gate, not a test of
the `mm_alloc_aligned` fragmentation/descriptor failure path.

## Physical source-linked observations (octal)

- Original unmodified allocator `mm_arena_fits_v1260=002154`
  is entered by current slot1 with requested `0130000`
  words, APR alignment `002000`; the verifier reads the
  live original MM arena descriptors and proves that this
  request is impossible in *each* physical arena.
- Original requester-only fatal path at `013713` is reached
  from current slot1. The original physical MM table remains
  **MM18** through the failed allocator call and fatal entry,
  including its retained RAW `111200..120000` owner3,
  provisional full PROCESS `120000..130000` owner2, target
  escrow, private CTX and original ROOT.
- Genuine parent `proc_exit_current=013655` then releases
  exactly the parent u-area and PROCESS allocation:
  **MM18 -> MM16**, while foreign child3 remains under
  TRANSITION, orphaned to parent0. No peer MM disappears.
- Genuine healthy children slots 4,5,6 execute independent
  original EXIT instructions, each completed by an original
  idle checkpoint before the next EXIT. Their exact six
  KERNEL_DYNAMIC/PACKED MM extents disappear:
  **MM16 -> MM10**. All unrelated extents remain exact.
- Sole remaining live process slot3 has descriptor
  `047017600001` and VMbase0, original saved CTX_PC
  `340000016704`, FDCTL `000000004010`, and original
  uarea word067 escrow `040000120000`. It retains RAW
  `111200..120000` owner3 and foreign provisional full
  `120000..130000` owner2. ROOT remains unchanged.
- THREE original slot0 `proc_finish_service_v881=013065`
  retries execute at PCLK `024075`, `025075`, `026075`
  octal, with separate native idle-loop completion between
  retries. Spacing is `01000` octal (512 decimal) ticks,
  shared pending/backoff remains armed at capped `01000`,
  and the genuine PI6 interrupt saved word `340000017565`
  identifies interrupted original idle instruction.
- The simulator is **operator stopped**, not a native
  guest HALT. No forced FINALIZE, owner correction or
  speculative reclamation is performed.

The strict physical verifier checks the source-built USER
BRK gate, compiler map addresses, KCORE/PURE byte hashes,
genuine original MM arena checks, exact return-to-fatal
source path, parent-only MM release, three independent healthy
child exits, identical MM10 quarantine across three genuine
clock-spaced native retries and actual PI6. FOUR targeted
physical negative mutations reject a false impossible BRK,
foreign target reownership, lost executive escrow and
premature final-process deletion.

## Reproduction

    cd $HOME/git/daimos-testkit
    export DAIMOS_REPO=$HOME/git/DAIMOS PDP10_PREFIX=$HOME/cross
    export TMPDIR=${TMPDIR:-$HOME/tmp}
    export V1915_SOURCE_DIR=$TMPDIR/daimos-k05-orphan-oom-v1915-source-v1
    make test-pure-k05-orphan-oom-build-v1915
    export V1915_BUILD=$TMPDIR/pure-brk-pressure-v1614.e7CvWN/build
    export V1915_PROBE=$TMPDIR/daimos-k05-foreign-target-v1906-probe/probe.clean
    export V1915_WORK=$TMPDIR/daimos-k05-orphan-oom-v1915-physical-v4
    make test-pure-k05-orphan-oom-physical-v1915
    make test-pure-k05-orphan-oom-audit-v1915

The source build emits its own unique actual directory: use
the reported `build/` path instead of assuming the example
directory above is always present. The original matching
PURE probe and the 54-file compressed TSFS are checked by
the physical runner before original PDP-6 execution.

Two earlier local v1915 transcripts are deliberately not
accepted: v2 did not supply the process table through slot6,
and v3 mistakenly read KCORE's `proc_table` POINTER word
`024635` as the process table itself rather than dereferencing
the live physical base `045700`. The corrected v4 script
adds all 17 required full process table
snapshots; its strict source-linked verifier and four unsafe
negative controls PASS. This was a test controller issue,
not an observed production KCORE allocator bug.

Accepted SHA256:

- Normalized physical transcript `fc8ac14b4c1a31507d974982fb624a52abad72f2d15250c6683a609d9ea53d58`
- Physical source-linked controller `d0a6860c3fc8fb4979ec4f73dccd84d0d17f26281e8a7de36ed701e69b995bfc`
- Original fixed KCORE `a201a7fdcf481b436b06694e5dd55c9367036ebd9f64c630486f854b1a4f89be`
- Original optional PURE `09f65d0ca272986b462c63580eae3c4006490004cd060529ce40f10a55949351`

Physical evidence:
`$TMPDIR/daimos-k05-orphan-oom-v1915-physical-v4/`.
No production source, fixed RAM, KCORE/PURE IMAGE/BSS or
feature default changes. K05 remains OPEN for other allocator
fault paths, PI6 interleavings, permanent unknown ownership,
and cross-platform integration. K06-K09 OPEN. RAW PURE and
mode3 remain default OFF.
