# DAIMOS/PDP-6 native Type-551 first block-number mark, v1524

Date: 2026-11-12. Regression for the PDP-6 Type-551 SIMH
implementation, discovered during DAIMOS KCORE P0-B secondary
DTFS full-guest acceptance.

## Observed defect

The existing production DECtape controller/Type-136 source passes
physical DTC3 writes and reads at blocks 1, 0144 and 0200, but
failed a physical block-zero write from a freshly started tape
when running on the previously installed simulator.

The simulator initializes selected-tape status to DTB_REQ,
and emits the very first forward block-number mark while this
status is still pending. The FNC_SRCH path required DTB_ACT,
but did not transition the pending search to active until a
subsequent block; block-zero's RBN0 was never delivered to the
already-armed Type-136. As a consequence v1520's physically
reserved block-zero volume identity could not be written by
the target on that simulator, even though its directory at
physical block 0144 was accessible.

## Test implementation and requirements

`daimos-dtc-first-mark-v1524.sh` source-links actual DAIMOS
`tape_io.s` and `storage_router.s` with the existing actual
PDP-6 PI/DCT test harness. Three isolated cases use independent
disposable, host-initialized native DTFS images on **DTC3**:

- block 000000: first physical RBN search and one-block write/read
- block 000001: adjacent ordinary block write/read
- block 000144: ordinary native DTFS directory-block write/read

Each check writes a distinct 128-word pattern and verifies its
full physical readback in native PDP-6 instructions. Simulator
startup, request selection, search interrupts and data channel
completion are real; no peripheral stub substitutes the tape.
The fixture never touches a user's actual tape.

Set `SIMH_PDP6` to the simulator to be tested. Optional
`DTC_PRE_FIX_SIMH_V1524` points to a known pre-fix simulator
and must reproduce a real native FAIL on block zero; its
ordinary blocks are separately covered by the main test.

The simulator fix is intentionally narrow: upon the first
forward block-number mark for FNC_SRCH, promote DTB_REQ to
DTB_ACT *before* forwarding that mark to the Type-136. This
preserves the controller's original status model and does
not move DTFS identity or invent an unverified media format.

In a separate full 256K `ROOT=auto BOOT=dsk` guest, real
target `MKFS.DTFS` returned and `FSCK.DTFS NATIVE OK`
was printed for physically attached DTC3. This proves a
real target physical formatting/checking path, **not**
a mounted provider: KINIT deliberately does not install
DTFS/TSFS MRES for disk-selected roots. The old v578
guest had an incorrect success oracle which treated
the pre-existing D6FS mountpoint STAT as successful
DTFS mounting despite actual MOUNT and UNMOUNT errors.
Its validation now requires actual FSINFO/MOUNT
publication, no command error, and retirement.

The remaining genuine DTC-selected root, secondary
mounted-DTFS FILE/cwd/dirty error/return/replacement
guest matrix is OPEN. See
`DAIMOS/design/kcore-dtc-first-mark-v1524.md`.
