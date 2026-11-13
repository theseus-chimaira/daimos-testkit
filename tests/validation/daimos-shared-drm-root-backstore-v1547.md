# v1547: full physical shared Type-236 root and BACKSTORE

Date: 2026-11-13. KCORE P0-A actual 256K KCC PDP-6 acceptance.

## Real full-guest test

`daimos-shared-drm-root-backstore-fullguest-v1547.sh` generates
the original v1541/v1511 full F07 swapped-process guest, changing
**only its disposable boot configuration** from `ROOT=disk
BOOT=dsk` to `ROOT=drum BOOT=drm`. All four root DR0..DR3 D6FS
images are built by the normal production `mkdsk`/`mkd6fs`
recipes. The kernel's existing four-member BLOCKSET VOLUME
mapper supplies BACKSTORE from the selected drum root's tail.

The test-only v1511 controller observer selects the first real
Type-236 physical BACKSTORE WRITE with enabled swap and allocated
backing blocks; it redirects the completed live request descriptor
at PI2 into the unchanged driver's actual error-completion path.
No KCORE service-return value, HALT instruction or error state
is forged by the test. It is a genuine simulator physical PI2
completion with a *selected injected error branch*, not proof of
actual detached drum media or a native hardware ERROR register.

The real PDP-6 HALTs at octal `003747` (fixed v1515 reason 2),
not `003743` (root HALT). Actual post-HALT linked observations:

| Witness | Octal |
| --- | --- |
| v1515 fixed entry | 003740 |
| actual HALT | **003747** |
| selected Type-236 PI2 error count | 000001 |
| BACKSTORE enabled | 000001 |
| original owned BACKSTORE blocks | **000320** |
| `device_region_map` | `400000000000` |
| `volume_data_blocks` | `000000075774` |
| `vfs_namespace_root` | `060101000000` |

SIMH boot switch 3 confirms the DR root profile. The DRM
high-half selector `400000` and nonzero VOLUME data region
confirm that the mapped BACKSTORE is on the physical selected
DRM root's underlying member set, not the separate auxiliary
Type-236 unit of the original v1542 disk-root guest.

Four clean periodic pre-error sampler observations have zero
injected PI2 errors. The v1542 strict independent verifier
accepts the exact linked HALT and live owner/PI2 evidence,
rejecting nine deliberately corrupted source/evidence mutants.
The v1547 verifier adds checking the actual root switch, DR0
root image attachment, DRM selector, nonzero VOLUME and published
D6FS root vnode. The old v1075 runner's nonzero return is due
to the intentional HALT; the v1547 acceptance script exits 0.

## Reproduce

```
export TMPDIR="${TMPDIR:-$HOME/tmp}"
export DAIMOS_REPO="$HOME/git/DAIMOS"
export PDP10_PREFIX="$HOME/cross"
sh tests/validation/daimos-shared-drm-root-backstore-fullguest-v1547.sh
```

Original evidence SHA-256 (guest console, raw SIMH, KCORE map,
simulator boot configuration respectively):

```
00cec8140ba1c6b4eeac49616827e84512ea4eff472fc62758ae687153b857eb
694aebc4f6ada11c8a57ea3e819320479389f546eab584ea1d92e6a8ce2ed0d0
eae83de5108b6ca20b04e56c729bb19e9208caad6cd532d0a16f3235946bfe00
6b03d0ebef0c88827015f7d8521ee8974b8ecf98daeacd5c19e12215d333ed8e
```

Retained run: `$TMPDIR/daimos-oom-requester-live-v1075.XRd74N`.

## Remaining acceptance

Native v1546 proves root-first and swap-first ordering with
combined source but controlled physical completion. Actual
booted v1547 demonstrates **BACKSTORE-first** loss on the same
physical DRM root set with real owned swap blocks. A live
**ROOT-first** failed transfer while BACKSTORE owns blocks has
not been physically demonstrated. P0-A stays open for that
last shared-order physical profile. No production KCORE source,
ABI or permanent RAM changes were made for v1547.
