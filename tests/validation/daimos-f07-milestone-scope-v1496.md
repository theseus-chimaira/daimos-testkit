# v1496: F07 milestone counting excludes SIMH host banners

The physical 256K v1494 BACKSTORE refusal run reached a genuine PDP-6
HALT with a clean final BACKSTORE usage count, but the inherited v1207
runner incorrectly reported `19/18 RUN children acknowledged`.

The saved `simh.out` shows **one** plus sign in the SIMH startup banner
(`edd19b17+uncommitted-changes`) and **exactly 18** after the F07
user program's initial `<` marker, followed by **exactly 18** `~`
reap markers. The extra character was a host simulator source-state
suffix, not a duplicate guest RUN or a new user process.

`daimos-oom-requester-live-v1075.sh` now checks the existing exact
18/18 counts only within the user milestone region: after the F07
`<` marker and before the SIMH HALT/examine output. It does not alter
the expected counts, guest source, kernel scheduler, OOM behavior,
wait/TERM checks, or any original F07 final marker assertions.

`daimos-f07-milestone-scope-v1496.sh` extracts and **executes the
actual runner's F07 milestone conditional** against synthetic host
banner contamination. PASS: extra host `+` ignored, while missing
user start, one extra user acknowledgment, one missing acknowledgment
and one missing reap all fail. The shared runner's shell syntax PASS.

This correction resolves only the spurious milestone-count error.
The same v1494 guest still had `v1494_terms=0` and one diagnostic
error; the full BACKSTORE refusal -> TERM -> PREVM -> final owner
acceptance remains **OPEN** pending v1495's independent witnesses.
