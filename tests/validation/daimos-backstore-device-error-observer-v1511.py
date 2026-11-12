#!/usr/bin/env python3
"""Inject two real Type-270 completion error paths into a disposable guest.

The first selected swap owner is established by the already accepted v1508
checked-release experiment, after a real successful physical payload read.
On its next two actual slot-0 BACKSTORE reads, replace the Type-270 PI5
IDLE completion with the production PI5 controller-error branch. The normal
DSK driver completes the private descriptor with failure, updates its error
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
    driver = root / "drivers/dsk_io.s"
    backing = root / "storage/backstore_entry_v484.s"

    source = bridge.read_text()
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
    old = ("        movei 1,-2(017)\n"
           "        pushj 017,dsk_start_active\n"
           "dsk_runtime_slot0_wait:\n")
    new = ("        movei 1,-2(017)\n"
           "        ; Arm only after prior active/queued I/O is drained.\n"
           "        ; The following request is exactly the target read.\n"
           "        skipn daimos_v1511_this_read\n"
           "        jrst daimos_v1511_start_normal\n"
           "        setzm daimos_v1511_this_read\n"
           "        setom daimos_v1511_error_active\n"
           "daimos_v1511_start_normal:\n"
           "        pushj 017,dsk_start_active\n"
           "dsk_runtime_slot0_wait:\n")
    source = replace_once(source, old, new, "exact slot-0 disk request")
    old = ("dsk_pi_idle:\n"
           "        cono 0270,0\n"
           "        skipn 2,dsk_active_request\n")
    new = ("dsk_pi_idle:\n"
           "        cono 0270,0\n"
           "        ; v1511: physical controller reached PI5 completion.\n"
           "        ; Route the selected read through the REAL error\n"
           "        ; completion, request wakeup and accounting path.\n"
           "        skipn daimos_v1511_error_active\n"
           "        jrst daimos_v1511_pi_normal\n"
           "        setzm daimos_v1511_error_active\n"
           "        aos daimos_v1511_device_errors\n"
           "        jrst dsk_pi_error\n"
           "daimos_v1511_pi_normal:\n"
           "        skipn 2,dsk_active_request\n")
    source = replace_once(source, old, new, "DSK PI5 completion")
    old = ("dsk_fail_runtime:\n"
           "        aos mfsdev_storage_errors+2")
    new = ("dsk_fail_runtime:\n"
           "        ; Also retire a test-only injection arm if hardware\n"
           "        ; failed independently before reaching IDLE.\n"
           "        setzm daimos_v1511_error_active\n"
           "        aos mfsdev_storage_errors+2")
    source = replace_once(source, old, new, "error descriptor retirement")
    driver.write_text(("        .globl daimos_v1511_this_read\n"
                       "        .globl daimos_v1511_error_active\n"
                       "        .globl daimos_v1511_device_errors\n") + source)

    source = backing.read_text()
    source += "\n; v1511 disposable real Type-270 error-path witnesses.\n        .bss\n"
    for name in ("this_read", "error_active", "device_errors"):
        label = "daimos_v1511_" + name
        if label + ":" in source:
            raise ValueError("v1511 duplicate diagnostic symbol " + label)
        source += "        .globl %s\n%s: .block 1\n" % (label, label)
    backing.write_text(source)


if __name__ == "__main__":
    if len(sys.argv) != 2:
        raise SystemExit("usage: v1511.py DISPOSABLE-KERNEL-ROOT")
    inject(Path(sys.argv[1]))
