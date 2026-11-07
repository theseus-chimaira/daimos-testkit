# v1306: Read-only live SIMH swap-pressure trace

This testkit-only opt-in lets a host operator observe a live PDP-6
pressure guest while it executes.  The Linux/Android host sends a
SIMH console interrupt (Ctrl-E), reads the live PC and selected
linked KCORE words with `examine`, then issues `go` to resume.
No DAIMOS source or guest memory is changed.  The brief CPU pause
can affect timing and must not be used for scheduler throughput
measurements.  Ordinary F07 acceptance retains the uninstrumented
default simulator launch.

## Run the full 24K-BSS pressure guest with periodic diagnostics

From the Android/Termux shell:

```sh
export TMPDIR=${TMPDIR:-$HOME/tmp}
export DAIMOS_REPO=$HOME/git/DAIMOS
export PDP10_PREFIX=${PDP10_PREFIX:-$HOME/cross}
export KEEP_TEST=1 V1306_LIVE_SAMPLER=1
export V1306_INTERVAL=60 V1306_COUNT=3 V1306_TIMEOUT=1810
sh "$HOME/git/daimos-testkit/tests/validation/daimos-swap-no-partner-fullguest-v1304.sh"
```

The wrapper prints the versioned test work directory.  While it runs,
follow `$work/simh-sampler.log` for compact live summaries or
`$work/simh.out` for the guest-only PDP-6 console transcript.
The full console/debugger transcript is retained separately at
`$work/simh.out.raw-v1306.log`, so debug commands and their results
cannot contaminate the strict F07 guest marker sequence.
Each sample includes PC, real scheduler timer, scheduler cursor,
run-queue head, pressure cooldown and counters for swap-out, swap-in,
failed swap-in allocations, exchanges and exhausted exchange scans.
The linked addresses come from the disposable guest's `addresses`
file, not from historical hard-coded kernel locations.

After an ordinary HALT, the sampler automatically executes the
original boot command file's postflight `examine`/`exit` sequence,
retaining existing memory-resource acceptance evidence.  The
v1303 physical result checker reads the guest-only post-HALT memory
observations rather than intermediate sampler records.  The original
`boot.ini` is never modified; a temporary same-directory command
file omitting the postflight sequence is removed afterward.

The test does not accept ordinary swap progress as proof of real
no-partner pressure.  The full guest must pass all original RUN,
OOM, witness, TERM/WAIT and MM/backing cleanup checks, and v1303
must additionally observe actual MM failure, pressure and cooldown.
A v1303 exit code of 3 means the no-partner condition was **not**
demonstrated, even when the guest completed successfully.

## Short read-only sampling check

Against an existing disposable 256K PDP-6 boot fixture, invoke
`daimos-simh-swap-live-sampler-v1306.py` with its `--simh`, `--ini`,
`--addresses` and `--log` arguments, plus `--interval 3 --count 2
--timeout 25 --stop-after-samples`.  This intentionally stops the
guest after two measurements and **never** claims full acceptance.
The testkit Makefile target
`test-daimos-simh-swap-live-sampler-v1306` checks the complete PTY
interrupt/examine/GO/post-HALT mechanism with a protocol stub and
a missing-symbol negative control.  The real SIMH smoke also passes
with two read-only PC/timer snapshots.

The standalone `test-daimos-swap-no-partner-v1304-preflight` target
checks the generated disposable guest runner's shell syntax without
building an image.  The 24K-BSS physical guest has not yet completed
with the live sampler enabled.  In particular, none of the available
real F07 runs has observed a swap-in allocator error or no-partner
cooldown; the kernel liveness question remains OPEN.
