# DSH phase-one history validation — 2026-10-11 v1

Using a fresh writable D6FS image and ROOT DSH login, the native SIMH
harness ran `probes/daimos-dsh-background-append-20261011-v1.txt`:
**6/6 PASS**. Two independent background DSH workers appended distinct
records to `/CONFIG/BGAPP`; `WAIT` joined both workers; readback preserved
HEADER, ALPHA and BETA, the parent remained usable, and HALT completed.
This is a live multiprocess test, not exhaustive forced-interleaving coverage.

The history loader now warns `DSH: HISTFILE DAMAGED; VALID PREFIX LOADED`
when `u_text_gets6` reports malformed/truncated data. Valid prior entries
are retained; the file is **not** truncated or automatically repaired.
The host history contract test checks this guard and warning. A newly built
PDP-6 image passed normal history write/readback/HALT 3/3 and same-disk
reload 1/1, with `d6fsck` reporting CLEAN between boots.

**Not yet tested:** inject an actually truncated/corrupted S6REC tail on
D6FS and validate its warning/prefix behavior under SIMH. Automatic repair
requires cross-process serialization and must not be performed blindly.
