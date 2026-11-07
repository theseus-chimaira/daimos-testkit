# v1326: booted 256K swap-in no-partner using real resident MM pins

This is a disposable F07 experiment to construct a physically valid
case in which `proc_swap_in` cannot acquire a process image and the
remaining resident exchange candidates cannot be selected by the
production reclaim or exchange rules. It does **not** inject an
allocator error or alter production swap-in/reclaim/scheduling code.

The v1322 (8K) and v1323 (1K) owner allocations both failed during
their test-only preparation after 18 additional 24K-word user
processes were admitted. Thus extra allocations are not a reliable
way to create the desired pressure. This new fixture instead uses
the real `mm_pin` and `mm_unpin` for **existing process extents**.

The fixture is inserted only into the disposable `native_sys_brk`
test hooks after the v1323 setup. At the normal original test stage
after all 18 children are admitted, test INIT enumerates the current
process table and pins stable resident user images that are not
already pinned. The original owner-tagged v1204 test array records
each base, and its counters record the pin count, exact release and
error status; no new BSS reservation is needed beyond that existing
test-only fixture. The OOM requester PID is passed in the *high*
18 bits of the test-only BRK sentinel, excluded from pinning so its
ordinary fatal OOM teardown remains possible. The low 18-bit
sentinel remains distinct from production BRK requests.

The parent's original three 0100-octal-tick sleeps allow physical
PI6/scheduler pressure while the resident extents remain pinned.
Before ordinary requester/provider/child TERM/WAIT teardown, the
parent issues the test-only release sentinel and unpins every base
in reverse order. An unpin failure is not hidden or ignored.

The v1326 snapshot verifier reuses v1203's exact real-MM physical
extent decoder. It requires multiple real process extents pinned at
the requester BRK OOM observation, exact successful release of all
fixture-owned pins, zero remaining count and no fixture error.
Independent negative assertions reject missing release, leaked
pins and false error clearance. The separate strict v1303 verifier
requires real `mm_alloc_aligned` resource failure, no-partner
cooldown, later successful swap-in and zero final backing leakage.
Merely pinning some processes does NOT constitute no-partner PASS.

The test executes production `proc_swap_victim`, which checks
`mm_is_pinned`, and the production equal-size exchange admission,
which also rejects pinned resident candidates. Actual disk I/O,
PI6 interrupts and process lifecycle run in the emulator.

The v1326 injector has already been assembled using the real PDP-6
assembler; the generated full-guest runner and v1324 early-HALT
sampler selftest PASS. Production DAIMOS remains unchanged.

```sh
export TMPDIR=${TMPDIR:-$HOME/tmp}
export DAIMOS_REPO="$HOME/git/DAIMOS" PDP10_PREFIX="$HOME/cross"
make test-daimos-swap-resident-pins-v1326-preflight

export KEEP_TEST=1 V1306_LIVE_SAMPLER=1
export V1306_INTERVAL=90 V1306_COUNT=14 V1306_TIMEOUT=1810
sh tests/validation/daimos-swap-no-partner-fullguest-v1326.sh
```

The full 256K guest remains an independent mandatory acceptance. A
guest HALT from pinning or teardown is a **test failure**, not a
kernel bug or proof of no-partner recovery. A guest with no actual
swap-in MM pressure remains **unexercised**. This adds no production
resident kernel words, extra MRES or speculative v1208 fallback.
