# P0-A v1539: single selected TSFS root member loss is fatal

Date: 2026-11-13. Tested with the current DAIMOS v1538 source and
full 256K KCC PDP-6 tape-root image. This is a **physical guest**
test using the actual Type-551/Type-136 SIMH controller and an
actual required root-file data read, not a fake permanent-loss bit.

Execute with the current, already linked TSFS-root image:

```
export DAIMOS_REPO="$HOME/git/DAIMOS"
export PDP10_PREFIX="$HOME/cross"
export DAIMOS_TSFS_PREBUILT_BUILD="$DAIMOS_REPO/build/system/boot/pdp6"
sh tests/validation/daimos-root-member-outage-fullguest-v1539.sh
```

The root is a **three-member TSFS volume**, with physical DTC0,
DTC1 and DTC2 attached at boot. The guest prints
`ROOTLOSS V1538 READY_DETACH` after successful root operations. In
v1539 mode the monitor sends only `DETACH DTC0` after this checkpoint;
**DTC1 and DTC2 remain attached**. A queued, instruction-delayed
console acknowledgment resumes PID1, which opens the actual
`/SYSTEM/INIT` image and reads noncached data. Any physical read
failure on the selected root after the driver's bounded recovery
must enter the fixed v1515 boot-root HALT. Unsuccessful syscalls or
normal PID1 exit are explicitly rejected.

Executed result: **PASS**. Real PDP-6 simulator reports
`HALT instruction, PC: 003743` (octal), matching the linked
KCORE map's *root-specific* HALT exactly; the script rejects the
BACKSTORE HALT and `PC=000000`. Only the selected DTC0 root member
was removed. Thus the root fail-stop decision is not conditional on
every member of a TSFS root set disappearing.

Full all-member physical root loss v1538 and independent secondary
DTC3 fault isolation under a live DTC4/MEMFS v1534 also PASSed on
the revised root policy. No KCORE source, driver classification,
ABI, or DATA/BSS modification is needed for v1539.

Still open: full-guest D6FS disk/drum root loss, independent
BACKSTORE-unavailability escalation without false HALT on transient
PI/watchdog faults, and combined critical-storage loss acceptance.
