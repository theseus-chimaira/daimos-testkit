# SUPERVISOR: one APR block and compact LOGSTORE, 2026-10-12 v11

All memory sizes here are octal PDP-6 36-bit words unless explicitly
marked decimal. Production SUPERVISOR: **001177 executable + 000051
BSS + 000020 origin + 000400 stack = 001670**, rounded by PDP-6 APR
to **002000**. The v7 supervisor reserved 004000; the new default for
other executables remains 02000 stack words.

## Completed checks

- Full PDP-6 disk image builds with the modified DXR2 `ST2` host linker,
  DXR validator, filesystem image builders, kernel loader, and MRES.
- `daimos-init-supervisor-size-20261012-v8.sh` checks actual ST2
  metadata and the one-block VM bound.
- `daimos-supervisor-stack-metadata-20261012-v8.py` accepts valid ST2
  and rejects stacks smaller than 0400, larger than 02000, invalid tags,
  PURE images, and compressed images carrying ST2.
- Normal PDP-6 CTY boot, PID 1 SUPERVISOR, ROOT LOGIN, and DSH
  conformance **115/115 PASS** on a fresh v11 image.
- `probes/daimos-supervisor-compact-log-20261012-v8.txt` checks LOGDUMP
  sees a real INIT_READY source-1 record written through the four-word
  event syscall. Separate raw-media checks confirm LOGIN source-2
  persistence. PASS.
- `tests/fixtures/daimos-supervisor-inittab-max-20261012-v8.txt`
  configures eight services: one working TTY0 LOGIN and seven invalid
  maximum-length 102-character pathnames, each with a distinct TTY.
  Boot reaches ROOT LOGIN, writes seven RUN FAILED diagnostics, and
  LOGDUMP shows source-1 severity-4 records with distinct entry indices.
  PASS.
- `probes/daimos-logstore-persistence-20261012-v9.txt`: two independent
  cold boots with new disk images pass direct `LOGD; LOGDUMP` persistence.
- `daimos-logstore-auxstore-integrity-20261012-v11.py` reads the Type-236
  drum's physical AUXSTORE descriptor and LOGSTORE blocks, verifies
  standard record magic and commit trailer, and checks INIT_READY
  count and the seven distinct failure indices in maximum-service
  mode. The strict eight-entry fixture persisted nine valid events
  (INIT_READY, failures 1..7, LOGIN). PASS.

## Root cause of the persistence regression

LOGSTORE's AUXSTORE MINIT previously patched the direct backend with
relocated raw hardware I/O services (hardware address, buffer), but the
direct LOGSTORE path supplied unit, block, buffer. On Type 236 this
corrupted physical block zero instead of the requested LOGSTORE
records while the producer cursor advanced. The fix patches KCORE
validated disk/drum bridges that implement the expected ABI.
Both APPEND and the compact four-word EVENT now persist correctly,
and physical AUXSTORE descriptor integrity is tested.

## Reproduce the eight-service stress boot

Build a PDP-6 disk image with
`SYSTEM_INITTAB_TEXT=tests/fixtures/daimos-supervisor-inittab-max-20261012-v8.txt`
(absolute path relative to this testkit repository) and a **separate
versioned BUILD_ROOT**, passing the same modified host `dlink`,
`mkd6fs`, `mkinitfs0`, and `dxrcheck` tools. Then run
`tools/daimos-simh-harness-v6.sh` with
`--probes probes/daimos-supervisor-failure-log-20261012-v8.txt`.
Use the ordinary compact-log probe for the standard INITTAB image.
The working LOGIN must be on **TTY 0** for this harness's CTY session.

After shutting down the simulator on each fresh image, inspect its
drum zero image with, for example:

```sh
python3 tests/validation/daimos-logstore-auxstore-integrity-20261012-v11.py \
  "$TMPDIR/supervisor-persist-v11-build-d-max8/system/boot/pdp6/drum/dsk0.dsk" \
  --expect-max8
```

For the ordinary three-service INITTAB image, replace `--expect-max8`
with `--expect-services 3`. Do not infer persistence merely from the
producer status sequence or an APPEND return value.

## Pending separate acceptance

- Automated user-stack high-water watermark/guard tests.
- Deliberate killing and repeated respawning of an interactive LOGIN
  under high resource contention.
- Full 32K PDP-6 LOGIN-to-DSH EXEC acceptance.

The above omissions do not invalidate the measured single-APR-block
resident allocation, but must not be represented as already tested.
