# v1334: early 32K physical owner reservation for full PDP-6 swap tests

The experimental `daimos-swap-no-partner-fullguest-v1327.sh` builds a
disposable 256K PDP-6 F07 guest. It derives the established 24K-BSS,
18-extra-child RUN/TERM/WAIT test and reserves four 020000-octal-word
(8192-word) `MM_TYPE_KERNEL_DYNAMIC` extents, owner 075, while only
the six original users are active. These are genuine allocations
through production `mm_alloc_aligned_noreclaim` and are released
through production `mm_free` with exact type and owner.

The earlier v1322/v1323 attempts allocated additional owner extents
after 18 admissions; even a single 1K extent failed then. Early
reservation moves the allocation earlier without fabricating an MM
status or changing any production allocator or swap code. Original
v1207 test policy remains untouched; only the disposable generated
runner explicitly permits simultaneous F07 swap and extra owner
pressure. The separate verifier requires all four aligned physical
extents in the v1203 OOM MM snapshot and four exact typed frees.

The v1333 source extraction check verified four allocation iterations,
the production MM allocation and free calls, and the test-only early
lease precondition adjustment. The original v1327 script's generated
runner preflight PASSes. A real SIMH guest subsequently entered its
extra-child RUN phase without the `!t` test-owner setup rejection.
Do not infer a no-partner swap-in result from this intermediate
progress: the **final** v1303 source-linked MM failure, exchange,
cooldown, backing and HALT checks are required.

Run (original guest command; production source remains unchanged):

```sh
export TMPDIR=${TMPDIR:-$HOME/tmp}
export DAIMOS_REPO="$HOME/git/DAIMOS" PDP10_PREFIX="$HOME/cross"
export KEEP_TEST=1 V1306_LIVE_SAMPLER=1
export V1306_INTERVAL=90 V1306_COUNT=18 V1306_TIMEOUT=1810
sh tests/validation/daimos-swap-no-partner-fullguest-v1327.sh
```

Note: equal-size physical resident process peers may still be valid
swap-exchange partners. Reserving real physical memory alone does
not prove that the **no-partner** branch is reachable. The distinct
v1326 resident `mm_pin` experiment addresses partner eligibility;
combining mechanisms requires a separately verified fixture.

No KCORE/MRES size change, fallback code, fabricated allocation
failure or production kernel patch is part of this experiment.
