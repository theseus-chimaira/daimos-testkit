# v1670: event-boundary PDP-6 KINIT peak RAM, without guest instrumentation

Accepted parent DAIMOS v1669:
`e2c1d0d68eb1e46e9a7b6b27f79863ce10d9cc91`.

No DAIMOS kernel, KINIT, runtime ABI or permanent memory is
modified. Only daimos-testkit gains simulator-side instrumentation,
with design/state records in DAIMOS and pdp10-doc.

## Scope and physical coverage

`run-physical-v1670.sh` builds two source-matched GCC lowmem
TSFS/PURE KINIT images or accepts existing source-built paths.
The general ROOT=tape image carries the transient DISK SWAP MRES
candidate; the v1668 strict image removes it. Both images install
the unchanged PURE MRES and leave bitmap mode3 disabled. Each
image is booted on a real SIMH PDP-6 at physical 48K and 64K,
using isolated copies of all four generated DECtape media and
no attached DSK/DRM auxiliary BACKSTORE.

`make-probe-v1670.py` takes every address from the actual linked
KINIT/KCORE maps. SIMH execution breakpoints sample MM before
the operations that can alter its physical allocation/free map:

* `mres_init` (start, after MM boot arena initialization);
* `mm_extent_insert` (physical MM extent insertion);
* `mm_boot_reserve` (permanent MRES conversion);
* `mm_add_free` (reclaim/free arena publication);
* `mm_free` (exact owner deletion);
* `mm_process_shrink_pinned`, `mm_process_grow_pinned` and
  `mm_compact` (other possible physical size/movement paths);
* `vm_enter_initial_user` (terminal snapshot, after successful
  source-image/stack release and initial user VM construction).

Every probe samples actual `mm_core_words`, extent capacity/count,
all 3 arena words, the first 40 possible two-word MM extents and
the patched permanent resident immediate. The custom simulator
break actions perform `examine` and continue; at the terminal
entry they examine and exit. The first breakpoints during early
arena setup precede `mres_init` and are intentionally excluded;
the trace interval begins only once the initialized MM arena map
exists. There is no added guest probe or resident scanner.

`trace-v1670.py` rejects wrong/missing/duplicate physical fields,
impossible MM capacity, unsorted or overlapping extents, invalid
owner type, impossible core bounds, nonconserved allocator words,
unexpected compaction/VM resizing, failed KINIT, or an absent
terminal handoff. `compare-v1670.py` recalculates min free/max
nonfree from EVERY event, checks both physical core sizes, and
compares the terminal original-MM state and measured peak with
the independently linked image-end difference. It rejects a
forged summary even if its samples are otherwise intact.

## Actual source-built PDP-6 results

| Core | General event count | Strict event count |
| --- | ---: | ---: |
| 48K | 53 | 52 |
| 64K | 53 | 52 |

At both core sizes, general KINIT records 20 extent insertions,
12 MRES boot reservations and 19 arena-add/free entries AFTER
MM-ready, plus start/end markers. Strict KINIT records the same
20 extent insertions and 12 reservations but 18 arena-add/free
entries. No `mm_free`, compact or in-place process extent resize
events occur in this traced interval. Each sample passes physical
MM geometry and owner-state conservation.

| Physical core | General minimum sampled free | Strict minimum sampled free | Free improvement |
| --- | ---: | ---: | ---: |
| 48K | 11944 | 13821 | **+1877 words** |
| 64K | 28312 | 30189 | **+1877 words** |

| Physical core | General maximum sampled nonfree | Strict maximum sampled nonfree | Reduction |
| --- | ---: | ---: | ---: |
| 48K | 37208 | 35331 | **-1877 words** |
| 64K | 37224 | 35347 | **-1877 words** |

The largest sampled occupied/reserved physical core point is
exactly the `mres_init` boundary in both profiles and at both
core sizes, before permanent MRES installation. The peak
difference matches the v1668 **1877 GCC lowmem transient linker
word reduction**, this time measured using the live PDP-6 arena
map rather than inferred from link addresses.

At first `vm_enter_initial_user`, both variants have the SAME
physical free MM and the SAME installed resident/owner totals:

* 48K: 26421 MM free, low resident 17725, MM allocated 4958
  words (4096 process APR plus 862 kernel dynamic), 8 extents;
* 64K: 42773 MM free, low resident 17741, MM allocated 4974
  words (4096 process APR plus 878 kernel dynamic), 8 extents.

The eventual user-entry free delta is **zero**. This is
consistent with complete transient KINIT reclamation and the
same installed PURE-only runtime memory backend, unlike the
intermediate v1669 pre-reclamation checkpoint where net managed
free changed by only +66 words.

## Strongly bounded claim: not all-instruction runtime peak

The measured high-water is the maximum **stable allocator-event
boundary** nonfree count after MM-ready and before the initial
user VM handoff. These breakpoints cover known KINIT MM
free/extent-changing entry paths; the trace rejects any entry to
compact or direct in-place process extent resizing, which are
not expected during KINIT. The hardware may briefly change
internal words between breakpoints within an MM operation.
The complete running process memory-pressure lifecycle after
initial user entry, MM pins, BCACHE/VFS scratch and compressed
mode3 restore are NOT observed here. Do not claim an exact
instruction-level maximum, whole-system temporal peak, or
production bitmap compression net RAM gain.

## Reproduce and mutation checks

    DAIMOS_REPO=/path/to/DAIMOS \
      sh tests/validation/pure-kinit-peak-v1670/run-physical-v1670.sh

For already linked images set `V1670_GENERAL_BUILD` and
`V1670_STRICT_BUILD`, and use `KEEP_TEST=1` to retain all four
physical console traces, isolated media configs, real event
samples and JSON reports. The runner executes three independent
unsafe measurement variants and rejects each: an impossible
physical arena sample, missing first-user terminal breakpoint,
and a forged peak summary. A failed/timeout simulator run is
never treated as a successful physical trace.

Strict physical 32K, bitmap mode3 production reclaim, compressed
RUN/EXIT/WAIT/PI6, and sustained 48K/64K runtime process-pressure
peak accounting remain future acceptance gates.
