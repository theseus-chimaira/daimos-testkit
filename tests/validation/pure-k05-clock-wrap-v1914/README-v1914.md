# K05 v1914: original PDP-6 17-bit retry-clock wraparound

Date: 2026-11-24. **Scoped original 48K PDP-6 physical PASS.**

## Question and constraints

Does an unrepaired foreign-owned last orphan retain its exact MM
ownership and bounded retry interval across the original PDP-6
17-bit scheduler clock wrap? The original source masks the PCLK
epoch with `PROC_TIMER_CLOCK_MASK=0377777` (octal), subtracts
the previous retry epoch, masks again, and compares against the
shared `01000`-tick capped interval. A clock-wrap regression
could incorrectly cause an early retry, starve the last owner,
clear its pending marker, or force an unsafe terminal release.

The exact original source-built v1910 48K five-child guest,
fixed KCORE, optional PURE, compressed 54-file TSFS, and v1913
permanently foreign-owned last-orphan controller are unchanged.
The entire v1913 physical prefix, including full v1911 proof,
15 original capped retries, four PCLK PI6 checkpoints, and MM10
single last orphan, is revalidated by independent existing
positive physical oracles in this same actual simulation.

## Synchronized test-only clock rebase

Waiting from clock `043736` octal to the natural 17-bit wrap
would require many unrelated real simulator ticks. Instead the
controller stops the original guest at an original PI6 entry
after v1913's last physical checkpoint. It makes exactly TWO
test-only deposits, preserving the retry's pending bit and cap:

| Existing permanent KCORE word | Before | After (octal) |
| --- | --- | --- |
| `proc_timer_clock` at `024530` | `000000043736` | `000000377770` |
| `proc_finish_last_tick_v881` at `024532` | `401000043736` | `401000377770` |
| `proc_timer_next` at `024531` | `000000000000` | unchanged |

This is a **controlled clock/epoch leap**, not a natural
36-minute uptime proof. Both low-17-bit coordinates are
advanced together; no elapsed interval is fabricated or
accepted. The simulator does NOT deposit any MM owner, user
context, executable instruction, register, cleanup return,
process table word or scheduler completion flag. The original
PI6 `AOS` executes next, then all subsequent clock increments,
reaper scans, and idle returns are original kernel execution.

The original PCLK at `proc_sched_pi_tick=017225` first raises
the new clock to `0377771`. Seven additional DISTINCT original
PI6 breakpoints, each followed by a genuine original idle-loop
return at `proc_idle_loop=017552`, prove the exact transition:

    last before rollover    000000377777
    first after rollover    000000400000
    masked 17-bit low word  000000000000

The original 36-bit physical clock is NOT itself reset at the
17-bit frontier; its low 17 bits wrap while its higher bits
continue incrementing. `proc_timer_next` stays zero throughout.
The original pending retry remains `401000377770` across the
actual hardware rollover (no missed owner and no early retry).

## Actual post-wrap retries

| Genuine native retry | Raw PCLK (octal) | Pending retry epoch (octal) |
| --- | --- | --- |
| 1 | `0400770` | `401000000770` |
| 2 | `0401770` | `401000001770` |
| 3 | `0402770` | `401000002770` |

The first native slot0 reaper call at `013065` occurs exactly
`01000` octal (512 decimal) clock ticks after the rebase.
Two following reaper calls are each `01000` ticks apart and
each completes a distinct native `proc_idle_loop` return.
The original timer interval stays capped at `01000`, with
pending bit retained. No fake executable transitions or
simulator-only cleanup results are accepted.

All captured original MM10 extent rows and owners, ROOT,
sole slot3 orphan `047017600001` parent0/TRANSITION/VMbase0,
original PACKED RAW source `111200..120000` owner3,
foreign PROCESS target `120000..130000` owner2 (metadata
word `024707` after compaction), original saved CTX_PC
`340000016704`, FDCTL `000000004010`, exact existing uarea
word067 escrow `040000120000`, and all other FREE user slots
are identical across rebase, every PI6 and all three native
post-wrap retries. The guest never performs a native HALT;
the simulator is operator-stopped at the end of the proof.

Four independent unsafe physical transcript mutations all
reject: clock/epoch incoherence after the rebase, missing
physical hardware wrap, an early post-wrap retry and an
unauthorized owner2->owner3 change. One initially rejected
verifier run had hardcoded the nondeterministic v1913 last
clock as `042342`; this was corrected to verify the exact
source-linked physical clock in the SAME run (`043736`).
The original guest/source, controller and physical evidence
were NOT changed. This was a verifier expectation defect,
not an observed kernel or simulator defect.

## Reproduction

    cd $HOME/git/daimos-testkit
    export DAIMOS_REPO=$HOME/git/DAIMOS PDP10_PREFIX=$HOME/cross
    export TMPDIR=${TMPDIR:-$HOME/tmp}
    export V1914_BUILD=$TMPDIR/pure-brk-pressure-v1614.syLB4i/build
    export V1914_PROBE=$TMPDIR/daimos-k05-foreign-target-v1906-probe/probe.clean
    export V1914_WORK=$TMPDIR/daimos-k05-clock-wrap-v1914-physical-v1
    make test-pure-k05-clock-wrap-physical-v1914
    make test-pure-k05-clock-wrap-audit-v1914

The original v1910 source-built guest is reproducible with
`make test-pure-k05-parent-exit-build-v1910`; its actual build
directory and matched original PURE probe must be supplied.
The simulator checks the same original 54-file compressed TSFS
media before boot. The test requires no production rebuild.

Accepted SHA256:

- Normalized physical transcript `7b7d9afefbe9e2d59e8fc46876d22ce57e3538cb0cacc39ad6fd3d09c72fa705`
- Source-linked SIMH script `932f7607e91bb140e119158120f17938b643c1cfbec6bd74cef737fc42550c1f`
- Original fixed KCORE `a201a7fdcf481b436b06694e5dd55c9367036ebd9f64c630486f854b1a4f89be`
- Original optional PURE `09f65d0ca272986b462c63580eae3c4006490004cd060529ce40f10a55949351`

Physical evidence:
`$TMPDIR/daimos-k05-clock-wrap-v1914-physical-v1/`.
DAIMOS design:
`design/kcore-k05-clock-wrap-v1914.md`.
Permanent documentation:
`pdp10-doc/KERNEL/PURE-K05-CLOCK-WRAP-V1914.MD`.

**Scope:** one controlled near-wrap time rebase followed by
real original PDP-6 PCLK PI6 ticks, idle resumes and three
clock-separated native retries. This proves the specific
17-bit rollover ordering, NOT unbounded uptime or all clock
counter positions, other allocator faults or cross-platform
production acceptance. K05 remains OPEN; K06-K09 OPEN.
No production source, IMAGE, BSS, RAM or default policy
changed; RAW PURE/mode3 remain default OFF.
