# v1567 DTVOL2 media faults, physical interrupted CLEAN and cold boot

Date: 2026-11-14. **Real Type-551 and production KCORE acceptance PASS.**
P0-B remains OPEN; production DTVOL2 is strictly READ-ONLY.

## Independent physical cold boots from eleven crash images

`daimos-dtfs-v2-fault-media-v1567.py` changes only a disposable
578-block DTC3 image after checking a complete, valid original
DTVOL2/CLEAN record, its full 72-bit identity, seal and padding.
It constructs ten reject variants and one intentionally accepted
negative control. These first eleven are **host-created images**;
none is falsely described as an interrupted controller write.

`daimos-dtfs-v2-fault-fullguest-v1567.sh` boots the ordinary 256K
KCC PDP-6 with the unchanged production VFS/DTFS MRES and the
actual physical Type-551 transfer path for each independently
prepared tape. It verifies both production source files match the
supplied compiled image, and compares SHA-256 of the complete
DTC3 image before and after each guest, not just the RBN0 bytes.

| Image state | Guest result |
| --- | --- |
| Torn DIRTY state (new word4, old CLEAN word5) | RW and RO refused |
| Torn DIRTY seal (old word4, new DIRTY word5) | RW and RO refused |
| Torn CLEAN state (new word4, old DIRTY word5) | RW and RO refused |
| Torn CLEAN seal (DIRTY word4, new CLEAN word5) | RW and RO refused |
| Torn CLEAN half-word | RW and RO refused |
| Damaged identity complement | RW and RO refused |
| Damaged DTVOL2 magic | RW and RO refused |
| Damaged RBN0 padding | RW and RO refused |
| Valid DIRTY with damaged DATA block | RW and RO refused |
| Valid DIRTY with damaged directory block | RW and RO refused |
| Valid CLEAN with damaged unrelated DATA block | **RO admitted** |

All eleven actual cold boots and full tape hashes PASS. Some
torn-state constructions intentionally produce identical final
RBN0 bytes by different write orders. The last case is important:
RBN0 CLEAN cannot detect unrelated silent DATA corruption. It must
not be counted as a successful data-integrity check or a recovery.

## Actual partial Type-551 RBN0 CLEAN write

`daimos-dtfs-clean-partial-physical-v1567.sh` reuses the genuine
v1566 physical transaction. The script copies an EXACT current
production image, adds the test-only private DIRTY arm to the
copied DTFS MRES, and installs TWO private VFS labels only in the
copied KCORE: before the actual v1566 CLEAN provider call and on
its sticky WRITE_UNCERTAIN failure branch. Their linked octal
addresses are checked in the generated map and installed as
SIMH instruction breakpoints before the simulator boots.

In the first boot PID1 mounts a genuine DTVOL2/CLEAN DTC3
read-only after normal RW refusal. Its first UNMOUNT actually
calls the production v1551/v1552 MM-pinned physical DIRTY writer,
verifies DIRTY readback, and deliberately aborts without CLEAN.
The test-only mount RW/ARMED state is then set in the disposable
image. The next UNMOUNT reaches the first exact VFS breakpoint
just before the otherwise UNMODIFIED v1566 CLEAN operation.

With SIMH stopped deterministically, DETACH flushes the physical
DIRTY tape and the independent verifier proves that ONLY RBN0
words 4/5 changed from the original CLEAN image. The simulator
reattaches that exact tape and sets diagnostic
`PARTIALWRITE=0000:1`. On `cont`, the real Type-551 data channel
performs ONE physically changed 36-bit word of the CLEAN write,
then reports controller failure. The second exact breakpoint
proves resident VFS retained sticky WRITE_UNCERTAIN instead of
releasing the mount. DETACH flushes the damaged tape. The
byte-level verifier proves word4 is now CLEAN while word5 retains
the old DIRTY salted seal, with full 72-bit identity and every
other physical tape byte unchanged.

The guest resumes and confirms refused UNMOUNT, refused DTFS
FSINFO/CHDIR, retained poisoned owner/quiescence and healthy TSFS
root FSINFO, then exits cleanly. The copied torn physical image
is **cold booted a second time with the unmodified production
KCORE/MRES**. Real physical RBN0 reads refuse both RO and RW,
publish no DTFS slot and leave full-image SHA-256 unchanged.

The two SIMH breakpoints are test-only timing controls. The
physical Type-551 controller, actual v1551 DIRTY arm and actual
v1566 CLEAN writer, MM pin/free, VFS owner checks, sticky
failure policy and cold-boot rejection are production source,
NOT simulated provider callbacks. The instrumented first boot
and the unmodified second boot are separate processes.

An earlier asynchronous CTRL-E monitor attempt failed to stop
SIMH and was not accepted. The deterministic source-linked
breakpoint test replaces that invalid timing assumption;
the older v1529 diagnostic physical block-write test still PASSes.

## Reproduce

```sh
export TMPDIR="${TMPDIR:-$HOME/tmp}"
export DAIMOS_REPO="$HOME/git/DAIMOS"
export PDP10_PREFIX="$HOME/cross"
sh tests/validation/daimos-dtfs-v2-fault-fullguest-v1567.sh
sh tests/validation/daimos-dtfs-clean-partial-physical-v1567.sh
```

The partial physical test requires diagnostic SIMH
`$PDP10_PREFIX/bin/pdp6-v1529r5` with its v1529 changed-word
failure feature. An exact existing source-matched production
build can be supplied with `DAIMOS_V1566_BASE_BUILD`. The first
runner uses `DAIMOS_TSFS_PREBUILT_BUILD` if provided. Reusing
builds is optional; the scripts otherwise build isolated images.

## Limits and cost

The Type-551/136 driver supports one transfer owner at a time and
checks actual requested unit/RBN, but provides no durable physical
reel-generation token or mechanical lock. An operator can exchange
media between otherwise independently correct physical checks.
A matching RBN0 identity proves identity at the time of that read,
not continuous attachment during an ensuing WRITE. No software
patch pretending to fix this limitation was introduced.

Real partially written DATA/DIR on V2, same/replacement media
exchange DURING I/O, post-write reinsertion after a complete
legitimate RW user-data transaction, and an enforceable hardware
or operational media-identity interlock remain P0-B requirements.
The v1555 mandatory V2 READ-ONLY gate is unchanged.

**No production DAIMOS source or fixed/movable KCORE RAM change.**
The fixed KCORE low end remains octal `024364` from v1566.
P0-A closed; **P0-B OPEN**, P1-C/D/E unchanged, VERSION 0.5,
32K optimization HOLD.
