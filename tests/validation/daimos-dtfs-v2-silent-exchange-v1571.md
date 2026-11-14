# v1571: physical silent-reel-exchange negative proof

Date: 2026-11-14. **PASS as a negative safety witness** in two
independent full KCC/PDP-6 boots. Not an RW acceptance.

## Purpose and boundary

The previous v1527 real guest demonstrated that an OBSERVED DTC3
read failure marks READ_SUSPECT; the original stored 72-bit ID
must then match a physically reread RBN0 before old FILE reuse.
This does not answer whether Type-551 signals a reel changed while
the CPU is not accessing that unit. Test v1571 isolates precisely
this missing premise: exchange two valid CLEAN V2 reels without a
guest request or intervening controller error, then resume the old
mount. It is a NEGATIVE experiment, NOT permission for online
reel exchange or an additional production read/write feature.

## Exact physical execution

The harness `daimos-dtfs-v2-silent-exchange-v1571.sh` uses the
unchanged production KCORE and DTFS/TSFS MRES, not the disposable
v1568/v1570 writable test image. It builds two independent full
578-block DTVOL2/CLEAN media from current host `mkdtfs`, checking
complete RBN0 physical layout: V2 magic, two nonzero 36-bit IDs,
identity complement, CLEAN state, salted CLEAN seal, all 122
zero padding words, correct total geometry and DIFFERENT 72-bit
identities. Their whole-reel SHA-256 digests are captured BEFORE
the guest starts.

Genuine PID1 mounts original DTC3 READ-ONLY and verifies FSINFO and
STAT. Its previous unmodified RW mount attempt is refused. It emits
`V2EXCHANGE V1571 READY_SWAP` and blocks in real CTY READCHAR.
The host sends Control-E to the real PDP-6 SIMH monitor, DETACHes
DTC3 and ATTACHes the second independently stamped CLEAN V2 tape
before resuming. The SAME uninterrupted monitor episode performs
both physical operations; no guest DTC3 read, write, error or
READ_SUSPECT is possible between them. The simulator is used only
to create the deliberate externally changed media condition; it
does not substitute VFS, BCACHE, physical DTC or guest system calls.

Once ACKed, real PID1 calls FSINFO(1), STAT and CHDIR on the OLD
mounted DTFS owner. All **succeed**, despite the physically attached
reel having a DIFFERENT saved 72-bit ID. The guest calls CHDIR("/")
and successfully UNMOUNTs the still-published old VFS mount. The
visible guest sequence is:

```
V2EXCHANGE V1571 START
V2EXCHANGE V1571 READY_SWAP
V2EXCHANGE V1571 BLIND_SPOT_CONFIRMED
V2EXCHANGE V1571 PASS_NEGATIVE
```

The host compares both complete physical backing images to the
BEFORE fingerprints; all data remain unchanged. Two independent
full-guest runs passed with these fingerprints:

| Run | Original CLEAN | Replacement CLEAN |
| --- | --- | --- |
| r1 | `4f11cb69e0296ee5c1669fd3fddc83e0a448eb876afdedcdd52063c768e9f5a5` | `24717f7db247538cf3e0ba8cef05aa02fd96b9fcd5f594ffa2edbf80bd94f011` |
| r2 | `356f7014db23334899d3b0c7158cd453dca9d4d79d19510de77f9491c8da6171` | `488b3d19815610cc5cc8cf3411155c1caebde8fde2e3dc8fc36eb663252cf558` |

## Relation to actual hardware

The unchanged v1517 Type-551 selected/unattached status experiment
was rerun: `CONI 0214` gives octal `000004` for an unattached DTC0,
`001000` attached and `000004` after DETACH (same as unrelated
unattached DTC7); all four PDP-6 HALT PCs PASS. Those simulator
statuses only describe CURRENT controller availability, not a
durable media-generation counter after the unit is reattached.

The 1966 DEC TU55 instruction manual, section 3.3 (LOADING TAPE),
describes changing reels by setting REMOTE/OFF/LOCAL to OFF to
release the brakes, then returning to LOCAL or REMOTE. The switch
does not establish a guest-visible sticky reel-change epoch.
`pdp10-doc/HARDWARE/dectape.md` already establishes that original
Type-551 selection status cannot be treated as an independent
reel-removal signal. This test demonstrates the concrete software
consequence without asserting that a simulator's detach status is
exact physical-hardware behavior.

## Reproduction

```sh
export TMPDIR=${TMPDIR:-$HOME/tmp}
export DAIMOS_REPO="$HOME/git/DAIMOS"
export PDP10_PREFIX="$HOME/cross"
DAIMOS_TSFS_PREBUILT_BUILD="$TMPDIR/daimos-v1570-image-r1" \
    sh "$HOME/git/daimos-testkit/tests/validation/daimos-dtfs-v2-silent-exchange-v1571.sh"
```

The complete source-matched production KCC image may instead be
rebuilt and supplied as `DAIMOS_TSFS_PREBUILT_BUILD`.

## Release conclusion

The old verified identity, a clean V2 record, a quiet controller,
and a working VFS provider lease do NOT guarantee a single reel
remained installed. The v1554 before-WRITE physical RBN0 check
cannot prevent external exchange before the next physical WRITE.
Neither repeated reads nor transient controller error flags can
establish an atomic media-retention promise. Physical retention
must be enforced outside the software-only Type-551 interface.

Production v1555 V2 READ-ONLY veto stays mandatory; P0-B is OPEN.
No production KCORE/DTFS/driver source change, ABI, resident RAM,
per-mount memory or optional MRES growth in this stage. Fixed
KCORE low end remains octal `024364`, VERSION 0.5 and 32K HOLD.
