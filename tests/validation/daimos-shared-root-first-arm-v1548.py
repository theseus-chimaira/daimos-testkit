#!/usr/bin/env python3
"""Arm real Type-236 PI2 error for selected D6FS root, not swap.

Operate only on a disposable kernel copy already instrumented by v1511.
The root must be published and BACKSTORE must actually own blocks.
Do not synthesize a filesystem error or jump directly to HALT.
"""
from pathlib import Path
import sys


def once(text, before, after, label):
    if text.count(before) != 1:
        raise AssertionError("v1548 source anchor drift: " + label)
    return text.replace(before, after, 1)


def inject(root):
    fs = root / "fs/d6fs_runtime.s"
    swap = root / "fs/fs_mres.s"
    backing = root / "storage/backstore_entry_v484.s"
    code = fs.read_text()
    original = ("        jumpn   1,d6fs_get_block_cache_hit\n"
                "        movei   1,013(010)               ; embedded struct fs_backing\n")
    replacement = ("        jumpn   1,d6fs_get_block_cache_hit\n"
        "        ; v1548 disposable: this is a genuine D6FS BCACHE MISS.\n"
        "        ; Arm an actual DRM descriptor only for the selected root\n"
        "        ; and only while BACKSTORE still has owned disk extents.\n"
        "        skipn   backstore_enabled\n"
        "        jrst    daimos_v1548_root_unarmed\n"
        "        skipn   backstore_blocks_used\n"
        "        jrst    daimos_v1548_root_unarmed\n"
        "        skipn   daimos_v1511_device_errors\n"
        "        jrst    daimos_v1548_root_verify\n"
        "        jrst    daimos_v1548_root_unarmed\n"
        "daimos_v1548_root_verify:\n"
        "        move    1,vfs_namespace_root\n"
        "        came    1,[060101000000]       ; D6FS mount 1 only\n"
        "        jrst    daimos_v1548_root_unarmed\n"
        "        move    1,1(010)             ; actual requester mount\n"
        "        andi    1,077\n"
        "        caie    1,1\n"
        "        jrst    daimos_v1548_root_unarmed\n"
        "        move    1,backstore_blocks_used\n"
        "        movem   1,daimos_v1548_owner_at_arm\n"
        "        aos     daimos_v1548_root_arm_count\n"
        "        setom   daimos_v1511_this_read\n"
        "daimos_v1548_root_unarmed:\n"
        "        movei   1,013(010)               ; embedded struct fs_backing\n")
    code = once(code, original, replacement, "actual D6FS cache-miss read")
    code = ("        .globl backstore_enabled\n"
            "        .globl backstore_blocks_used\n"
            "        .globl vfs_namespace_root\n"
            "        .globl daimos_v1511_this_read\n"
            "        .globl daimos_v1511_device_errors\n"
            "        .globl daimos_v1548_owner_at_arm\n"
            "        .globl daimos_v1548_root_arm_count\n" + code)
    fs.write_text(code)

    code = swap.read_text()
    original = ("        setzm   daimos_v1511_this_read\n"
                "        skipn   daimos_v1494_faults\n"
                "        jrst    daimos_v1511_backing_continue\n")
    replacement = ("        ; v1548: swap I/O cannot steal the selected PI2 fault.\n"
                   "        setzm   daimos_v1511_this_read\n"
                   "        jrst    daimos_v1511_backing_continue\n")
    swap.write_text(once(code, original, replacement,
                         "disable earlier swap-read error trigger"))

    code = backing.read_text()
    code += ("\n; v1548 disposable selected-root/owned-swap witnesses.\n"
             "        .bss\n"
             "        .globl daimos_v1548_owner_at_arm\n"
             "daimos_v1548_owner_at_arm: .block 1\n"
             "        .globl daimos_v1548_root_arm_count\n"
             "daimos_v1548_root_arm_count: .block 1\n")
    backing.write_text(code)


if __name__ == "__main__":
    if len(sys.argv) != 2:
        raise SystemExit("usage: arm-v1548.py DISPOSABLE_KERNEL_ROOT")
    inject(Path(sys.argv[1]))
