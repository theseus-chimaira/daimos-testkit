# KCORE v1540: physical D6FS disk-root I/O fail-stop

Date: 2026-11-13. This is an actual PDP-6 SIMH physical-disk
detach acceptance using the current v1538 fixed-KCORE fail-stop
policy, **not** a controller-register permanent-loss detector.

Testkit command:

```
export DAIMOS_REPO="$HOME/git/DAIMOS"
export PDP10_PREFIX="$HOME/cross"
sh tests/validation/daimos-d6fs-root-outage-fullguest-v1540.sh
```

The versioned wrapper compiles the existing real PID1 root-read
guest against production KCC PDP-6 libc, then creates a PRIVATE,
full KCC 256K `ROOT=disk BOOT=dsk` system image using normal
`mkdsk` and `mkd6fs` production recipes. `SYSTEM_INIT_DXR` is
the normal image-generation argument that substitutes this guest
for `/SYSTEM/INIT`; no kernel shims or special D6FS fake driver.

The machine boots with four selected physical root disk members
DSK0..DSK3 and the actual D6FS MRES. After checked PID1 root
STATS and `ROOTLOSS V1538 READY_DETACH`, the SIMH monitor
DETACHes DSK0, DSK1, DSK2 and DSK3. The resumed guest opens
and reads real root-file data from `/SYSTEM/INIT`. A missing
required physical block, after the driver's normal bounded
recovery, must HALT through the v1538 service-level classifier.

**Executed PASS:** simulator `HALT instruction, PC: 003743`
(octal), exactly the selected root HALT at +3 instructions
after linked `kcore_critical_device_lost_v1515` (`003740`).
The verifier rejects a normal PID1 exit at PC zero, any
`ROOTLOSS V1538 FAIL_*` marker, no HALT, more than one HALT,
and a different HALT address. The run exercises actual
Type-270/136 disk transfer instructions.

An initial full run of the real disk image failed its testkit
setup because the old tape-root monitor wrapper required a
`break 060` instruction: disk Stage 1 correctly starts from
`go 020` directly. The shared wrapper now chooses the correct
SIMH monitor insertion anchor for disk vs tape boot and still
removes its trailing `exit` to permit physical hot-detach.
The already-built image then booted, detached and HALTed at the
exact root PC. **No production KCORE change was needed.**

Related physical acceptance: v1538 all TSFS root members lost,
v1539 one of three TSFS root members lost, and v1534 secondary
DTC3 physical write failure while selected root, independent
DTC4 and MEMFS survive, all PASS on the same root fail-stop
semantics. Source-linked v1538 D6FS 11 cases/5 mutants and
TSFS 12 cases/4 mutants protect root/secondary distinction.

This closes the positive **D6FS disk-root physical outage**
gate, not all P0-A. D6FS drum-root, mixed shared DEVICE/VOLUME
faults, noncritical disk/drum negative controls and a separately
safe BACKSTORE service failure policy remain open. Keep the
existing checked owner/PI rollback under transient errors.
