#!/usr/bin/env python3
"""Audit physical PDP-6 source/mount lifetime while six children PACKED.

No host emulation of the syscall result is accepted: the original C89
guest itself calls real VFS/DTFS syscalls while source is writable.
"""

import argparse
from pathlib import Path
import re
import runpy


def audit(kmap, plain_dxr, compressed_dxr, trace, source):
    h = runpy.run_path(str(Path(__file__).resolve().parent.parent /
                           "pure-full-restore-v1638/audit-v1638.py"))
    symbols = h["symbols"](kmap)
    sample = h["stage"]
    assert symbols["proc_swap_backing_busy"] == 0o3322
    assert symbols["proc_swap_mount_busy"] == 0o3431
    assert "MEM                                  48 K" in trace
    assert "PURE                              LOADED" in trace
    assert "DTFS                              LOADED" in trace
    assert "aaaaaax[B" in trace and "V1644_STAGE_B\n" in trace
    assert "[A" in trace and "V1644_STAGE_A\n" in trace
    assert "V1644_STAGE_PROTECTED\n" in trace
    assert "V1644_STAGE_RELEASED\n" in trace
    assert "V1644_STAGE_Z\n" in trace
    assert "HALT instruction, PC: 000000" in trace
    assert "HALT instruction, PC: 003776" not in trace
    for label in ("V1644_MOUNT_GUARD_ENTRY", "V1644_VNODE_GUARD_ENTRY"):
        assert trace.count(label + "\n") == 1
    assert "!" not in trace, "guest indicated rejected unexpected syscall"
    assert trace.index("V1644_END_A\n") < trace.index(
        "V1644_MOUNT_GUARD_ENTRY\n")
    assert trace.index("V1644_END_MOUNT_BUSY\n") < trace.index(
        "V1644_VNODE_GUARD_ENTRY\n")
    assert trace.index("V1644_END_VNODE_BUSY\n") < trace.index(
        "V1644_STAGE_PROTECTED\n")
    assert trace.index("V1644_END_PROTECTED\n") < trace.index(
        "V1644_STAGE_RELEASED\n")
    assert trace.index("V1644_END_RELEASED\n") < trace.index(
        "V1644_STAGE_Z\n")

    for fragment in ("#define P14_CHILDREN         6U",
                     "SYS_WAIT_STATUS_VALUE(status) != P14_STATUS",
                     "denied = p14_spawn(rd, 1U);",
                     "p14_check_busy_v1644();",
                     "p14_check_released_v1644();",
                     "dsys_unmount(p14_mount_v1643) == 0",
                     "dsys_unlink(p14_compressed_path) == 0",
                     "dsys_truncate(p14_compressed_path, 0UL) == 0",
                     "SYS_O_WRONLY | SYS_O_TRUNC",
                     "dsys_write_words(fd, &sentinel, 1U) >= 0",
                     "dsys_rename(p14_compressed_path, p14_renamed_v1644)",
                     "dsys_unlink(p14_renamed_v1644) == 0",
                     "dsys_rename(p14_renamed_v1644, p14_compressed_path)",
                     "dsys_unmount(p14_mount_v1643) != 0",
                     "dsys_chmod(p14_compressed_path, 0777U)",
                     "dsys_dtfs_mount(p14_device_v1643, p14_mount_v1643,",
                     "(void)p14_char('P');", "(void)p14_char('U');",
                     "(void)p14_char('Z');"):
        assert fragment in source, "guest source changed: " + fragment
    assert "SYS_MOUNT_RDONLY | SYS_DTFS_TYPE_NATIVE" not in source
    plain = h["dxr_words"](plain_dxr)
    comp = h["dxr_words"](compressed_dxr)
    assert plain[0] == comp[0] and plain[2] == comp[2]
    assert plain[1] >> 18 == comp[1] >> 18
    assert (plain[1] & 0o300000) == 0o200000
    assert (comp[1] & 0o300000) == 0o300000
    text_words = comp[2] >> 18
    skipped = (text_words + 0o20) & ~0o177
    raw = 0o10000 - skipped
    assert 0 < raw < 0o10000 and skipped > 0

    def snapshot(label):
        words, extents = sample(trace.replace("V1644_", "V1638_"),
                                symbols, label)
        assert words[symbols["vfs_namespace_root"]] >> 24 == \
            (7 << 6) | 1, "selected root changed from TSFS mount 1"
        if label in ("B", "A", "MOUNT_BUSY", "VNODE_BUSY", "PROTECTED"):
            # Slot 1's VFS policy bit must be clear: an RO refusal
            # is NOT proof of any PURE executable backing guard.
            assert not words[symbols["vfs_mount_policy"]] & 0o2, \
                "secondary mount is read-only, not testing PURE guard"
        assert any(a == 0o130000 and b == 0o140000 and kind == 1
                   and pin == 0 and owner == 1
                   for a, b, kind, pin, owner in extents)
        children = [(a, b, kind, pin, owner) for a, b, kind, pin, owner
                    in extents if kind in (1, 4) and 2 <= owner <= 7]
        return children

    orig = None
    for label in ("B", "A", "MOUNT_BUSY", "VNODE_BUSY", "PROTECTED"):
        extents = snapshot(label)
        assert len(extents) == 6, label
        assert {o for a, b, kind, pin, o in extents} == set(range(2, 8))
        assert all(kind == 4 and b-a == raw and pin == 0
                   for a, b, kind, pin, owner in extents)
        if orig is None:
            orig = extents
        assert extents == orig, "child immutable backing MM changed while busy"

    mount_entry = trace.split("V1644_MOUNT_GUARD_ENTRY\n", 1)[1].split(
        "V1644_STAGE_MOUNT_BUSY\n", 1)[0]
    assert re.search(r"Breakpoint, PC: %06o " %
                     symbols["proc_swap_mount_busy"], trace)
    assert re.search(r"(?m)^1:\s*0*2\s*$", mount_entry), \
        "unmount guard was not called with public mount 2"
    vnode_entry = trace.split("V1644_VNODE_GUARD_ENTRY\n", 1)[1].split(
        "V1644_STAGE_VNODE_BUSY\n", 1)[0]
    assert re.search(r"Breakpoint, PC: %06o " %
                     symbols["proc_swap_backing_busy"], trace)
    vnode_match = re.search(r"(?m)^1:\s*([0-7]{1,12})\s*$", vnode_entry)
    assert vnode_match
    vnode = int(vnode_match.group(1), 8)
    assert vnode >> 30 == 5 and ((vnode >> 24) & 0o77) == 2

    # Both stages follow a complete original six-PACKED guard phase.
    assert not snapshot("RELEASED"), "post-WAIT executable child still owns MM"
    assert not snapshot("Z"), "final child PROCESS/PACKED extent leaked"
    print("v1644: original RW secondary DTFS: chmod 0777, VFS RO bit 0")
    print("v1644: six PACKED children, each %06o octal RAW words" % raw)
    print("v1644: original mount guard PC %06o called with mount 2" %
          symbols["proc_swap_mount_busy"])
    print("v1644: original vnode guard PC %06o called with provider5/mount2" %
          symbols["proc_swap_backing_busy"])
    print("v1644: write/truncate/unlink/unmount refused; same-slot rename worked")
    print("PASS v1644: original 48K six-child restore, final UNMOUNT and HALT")


def main():
    p = argparse.ArgumentParser()
    for name in ("kcore_map", "plain_dxr", "compressed_dxr", "trace",
                 "guest_source"):
        p.add_argument(name, type=Path)
    args = p.parse_args()
    try:
        audit(args.kcore_map.read_text(encoding="ascii"),
              args.plain_dxr.read_bytes(), args.compressed_dxr.read_bytes(),
              args.trace.read_text(encoding="ascii"),
              args.guest_source.read_text(encoding="ascii"))
    except (AssertionError, ValueError, KeyError, UnicodeError) as exc:
        p.exit(1, "FAIL v1644 immutable source physical audit: %s\n" % exc)


if __name__ == "__main__":
    main()
