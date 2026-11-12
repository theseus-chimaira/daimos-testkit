#!/usr/bin/env python3
"""Inject two Type-167/236 drum PI2 error completions in a copied guest.

The first selected swap owner is established by the already accepted v1508
checked-release experiment, after a real successful physical payload read.
On its next two actual slot-0 BACKSTORE reads, redirect the selected drum
DR_DONE completion through the production PI2 error branch. The normal
DRM driver completes the private descriptor with failure, updates its error
counter, and wakes the original slot-0 caller. No successful read is faked.
The source-linked swap-in must then unpin/rollback MM and retain DISK/TERM.

Only disposable source copies are touched. This does not emulate broken
magnetic media or prove correct operation on arbitrary damaged hardware.
"""

from pathlib import Path
import sys


def replace_once(source, old, new, name):
    if source.count(old) != 1:
        raise ValueError("v1511 source anchor drift: " + name)
    return source.replace(old, new, 1)


def inject(root):
    bridge = root / "fs/fs_mres.s"
    driver = root / "drivers/drm236_io.s"
    backing = root / "storage/backstore_entry_v484.s"

    source = bridge.read_text()
    # v1511 is valid only for a DRM-backed BACKSTORE. A future profile
    # that routes backing to DSK must reject this experiment rather than
    # silently report zero injected errors (the original setup mistake).
    drum_route = ("blockset_direct_tail_drm_read:\n"
                  "        pushj   17,drm236_read_block\n")
    if source.count(drum_route) != 1:
        raise ValueError("v1511 requires actual Type-236 backing route")
    old = ("backstore_read:\n"
           "blockset_direct_tail_read:\n"
           "        setz    4,\n"
           "        jrst    backing_region_io\n")
    new = ("backstore_read:\n"
           "blockset_direct_tail_read:\n"
           "        ; v1511: select only the original real failed swap\n"
           "        ; owner, on its subsequent slot-0 read attempts.\n"
           "        setzm   daimos_v1511_this_read\n"
           "        skipn   daimos_v1494_faults\n"
           "        jrst    daimos_v1511_backing_continue\n"
           "        move    4,proc_sched_cursor\n"
           "        trnn    4,0400\n"
           "        jrst    daimos_v1511_backing_continue\n"
           "        andi    4,0377\n"
           "        came    4,daimos_v1494_slot\n"
           "        jrst    daimos_v1511_backing_continue\n"
           "        move    4,daimos_v1511_device_errors\n"
           "        caige   4,2\n"
           "        setom   daimos_v1511_this_read\n"
           "daimos_v1511_backing_continue:\n"
           "        setz    4,\n"
           "        jrst    backing_region_io\n")
    source = replace_once(source, old, new, "BACKSTORE read gateway")
    bridge.write_text(("        .globl daimos_v1494_faults\n"
                       "        .globl daimos_v1494_slot\n"
                       "        .globl daimos_v1511_this_read\n"
                       "        .globl daimos_v1511_device_errors\n"
                       "        .globl proc_sched_cursor\n") + source)

    source = driver.read_text()
    old = ("        add     017,kconst_3_3\n"
           "        pushj   017,storage_request_init\n"
           "\n"
           "drm236_runtime_retry:\n")
    new = ("        add     017,kconst_3_3\n"
           "        pushj   017,storage_request_init\n"
           "        ; v1511: identify the exact live stack descriptor,\n"
           "        ; even when an older DR request owns the controller.\n"
           "        skipn   daimos_v1511_this_read\n"
           "        jrst    daimos_v1511_request_normal\n"
           "        setzm   daimos_v1511_this_read\n"
           "        movei   5,-2(017)\n"
           "        movem   5,daimos_v1511_target_descriptor\n"
           "daimos_v1511_request_normal:\n"
           "\n"
           "drm236_runtime_retry:\n")
    source = replace_once(source, old, new, "exact drum descriptor creation")
    old = ("        trnn    1,DRM_DR_DONE\n"
           "        jrst    pdp10_pi_dispatch_done\n"
           "        cono    0400,DRM_DR_DESELECT\n")
    new = ("        trnn    1,DRM_DR_DONE\n"
           "        jrst    pdp10_pi_dispatch_done\n"
           "        ; v1511: genuine DP/DR completion for selected live\n"
           "        ; descriptor is routed through existing PI2 error\n"
           "        ; publication, accounting and wakeup code.\n"
           "        hrrz    2,drm236_active_request\n"
           "        jumpe   2,daimos_v1511_pi_normal\n"
           "        came    2,daimos_v1511_target_descriptor\n"
           "        jrst    daimos_v1511_pi_normal\n"
           "        setzm   daimos_v1511_target_descriptor\n"
           "        aos     daimos_v1511_device_errors\n"
           "        jrst    drm236_pi_error\n"
           "daimos_v1511_pi_normal:\n"
           "        cono    0400,DRM_DR_DESELECT\n")
    source = replace_once(source, old, new, "DRM PI2 final completion")
    old = ("        hrrz    1,drm236_active_request\n"
           "        jumpe   1,drm236_finish_return_v1079\n"
           "        movem   2,2(1)\n")
    new = ("        hrrz    1,drm236_active_request\n"
           "        jumpe   1,drm236_finish_return_v1079\n"
           "        ; A true earlier hardware error/timeout also retires\n"
           "        ; the disposable pending target, never a stale stack.\n"
           "        camn    1,daimos_v1511_target_descriptor\n"
           "        setzm   daimos_v1511_target_descriptor\n"
           "        movem   2,2(1)\n")
    source = replace_once(source, old, new, "DRM actual descriptor retirement")
    driver.write_text(("        .globl daimos_v1511_this_read\n"
                       "        .globl daimos_v1511_target_descriptor\n"
                       "        .globl daimos_v1511_device_errors\n") + source)

    source = backing.read_text()
    source += "\n; v1511 disposable Type-167/236 PI2 witnesses.\n        .bss\n"
    for name in ("this_read", "target_descriptor", "device_errors"):
        label = "daimos_v1511_" + name
        if label + ":" in source:
            raise ValueError("v1511 duplicate diagnostic symbol " + label)
        source += "        .globl %s\n%s: .block 1\n" % (label, label)
    backing.write_text(source)


if __name__ == "__main__":
    if len(sys.argv) != 2:
        raise SystemExit("usage: v1511.py DISPOSABLE-KERNEL-ROOT")
    inject(Path(sys.argv[1]))
