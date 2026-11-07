# v1322: Booted 256K PDP-6 F07 MM-owner occupancy experiment

Purpose: exercise the **real** swap-in MM resource-pressure and
no-eligible-exchange-partner path, which v1308's completed 24K-BSS
guest did not reach. The experiment modifies only an independently
built disposable kernel copy and its test INIT; the checked-out DAIMOS
production tree, MM allocator, scheduler and swap transaction are
unchanged.

The v1322 runner is derived from v1304 (18 additional 24K-word
pressure children, genuine DSK/D6FS, original strict OOM checks),
with the tested v1204 owner-tagged physical MM fixture enabled at
the stage **after** all child admissions and before requester BRK OOM.
Unlike v1206's 96 one-word extents, this distinct fixture allocates
one 020000-octal-word (8192-word) physical kernel-dynamic extent
through `mm_alloc_aligned_noreclaim`, owned by 075. It uses exactly
the original v1204 typed-MM release function after normal TERM/WAIT.
The distinct v1322 launch gate requires actual concurrent, swap-slot,
MM snapshot and owner-pressure modes together; it does not modify or
relax the original v1075/v1207 ordinary-acceptance mode contract.

The v1322 snapshot verifier reuses the actual v1203 MM image decoder
to reject invalid arenas, overlapping extents, bad types/owners and
invalid process residency. It checks the single test extent exists at
BRK OOM with correct APR alignment and exact owner, then verifies
the one exact free and zero remaining test-owner allocations.
The v1303 final checker separately requires source-linked typed MM
failure, no-partner cooldown, subsequent successful swaps, complete
HALT and zero leaked backing before claiming no-partner acceptance.
If the guest completes but does not enter no-partner pressure, its
result remains **unexercised** (classification exit 3), never a PASS.

Preflight without a guest build:

```sh
export TMPDIR=${TMPDIR:-$HOME/tmp}
make test-daimos-swap-physical-owner-v1322-preflight \
    DAIMOS_REPO="$HOME/git/DAIMOS" PDP10_PREFIX="$HOME/cross"
```

Full guest, retaining the evidence directories:

```sh
export TMPDIR=${TMPDIR:-$HOME/tmp}
export DAIMOS_REPO="$HOME/git/DAIMOS" PDP10_PREFIX="$HOME/cross"
export KEEP_TEST=1 V1306_LIVE_SAMPLER=1
export V1306_INTERVAL=90 V1306_COUNT=14 V1306_TIMEOUT=1810
sh tests/validation/daimos-swap-no-partner-fullguest-v1322.sh
```

The long run is bounded by the original 1800-second F07 guest
budget. The periodic live sampler captures read-only PC, scheduler,
swap, MM-failure and cooldown counters. Its intermediate samples
are **not** substitute evidence for the strict final guest checks.
An insufficient physical extent allocation or any original guest
milestone failure is a failed experiment requiring investigation,
not an acceptable no-partner result.

No production KCORE/MRES size growth or historical v1208/v1211
fallback is included.
