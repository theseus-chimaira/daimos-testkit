# v1575: operator-trust V2 poisoned-owner discard

Date: 2026-11-14. Full real PDP-6/Type-551 production-shaped guest
and independent cold boot PASS. This test proves the accepted weaker
operator-trust contract, not a mechanical reel lock.

The kernel now admits valid DTVOL2/CLEAN RW and still physically arms
WRITE_INTENT, keeps the MM scratch owner, checks write failures and
seals CLEAN on healthy unmount. The old v1531/v1570 provider-private
physical replacement verifier was replaced by a cache-only drain,
still under the existing serialized provider lease. All-process
FILE/cwd/PIPE/swap and MM pinned scratch checks are preserved before
and after the potentially sleeping lease acquisition.

The real 256K KCC PDP-6 PID1 on physical DTC3 performed a native
first DATA write and physically verified the original full DIRTY
RBN0 plus two DATA words. The Type-551 diagnostic wrote exactly one
changed 36-bit word of a second DATA request and failed. A complete
physical comparison established this damage: original RBN0145's
other requested word retained the old value and all other tape
blocks, including DIRTY RBN0, were unchanged. FILE/cwd blocked
root discard; ordinary close was refused; root DROP_FD followed by
cwd release was necessary. No valid data were reconstructed.

**Before changing physical reels**, root's DISCARDED_DIRTY step
successfully retired the unowned WRITE_UNCERTAIN mount. The guest
then attempted both an ordinary RO and RW mount of that *same*
original physical DIRTY reel: both refused. An independent CLEAN
DTVOL2 reel with a different complete 72-bit identity was then
attached. Normal RO mount, FSINFO, absent old FILE, refusal of
CREATE, UNMOUNT and retention of TSFS root all PASS.

Whole-media SHA-256 of the original DIRTY reel and the new CLEAN
reel was compared independently; neither physical image changed
during discard or remount. A separate *production* cold boot loaded
the exact preserved DIRTY image, refused RW and RO, published no
DTFS slot and did not write the physical reel. Final harness marker:

```
PASS v1575: production operator-trust discard, fresh mount and cold-boot refusal
```

The source-linked actual private `dtfs_discard_drain_v1575` entry
passed zero-hardware-I/O, cache-tag-clear and BCACHE invalidation;
two executable unsafe source mutations were rejected. The original
v1531 production VFS/FILE all-process source-linked suite still
passes with four rejected unsafe mutations; its test fixture was
updated with the MM aux slab and the modern KCORE constant imports.
The independently tested v1572 physical RW/CLEAN/reboot,
partial-DATA/reboot and read-error/return tests also PASS.

The test does not assert that DTVOL1 legacy tapes possess durable
DIRTY marking, or that a malicious or mistaken operator cannot
exchange a live reel silently. The operator quarantines damaged
legacy media; no automatic repair or remount of a poisoned V2 reel.
The old v1570 negative source test documents the earlier, stronger
different-reel verifier and is historical, not a current ABI gate.
