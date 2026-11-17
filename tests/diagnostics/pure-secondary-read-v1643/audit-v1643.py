#!/usr/bin/env python3
"""Audit genuine non-root DTC3 read failure during PURE FULL restoration.

Accept only a source-linked original 48K MM transaction which first
fails with -4, preserves the raw suffix, releases the full target,
and subsequently restores execution after the SAME DTC3 reel returns.
"""

import argparse
from pathlib import Path
import re
import runpy


def audit(kmap, mmap, dxr_dump, trace, source, plain, compressed, manifest):
    h = runpy.run_path(str(Path(__file__).resolve().parent.parent /
                           "pure-full-restore-v1638/audit-v1638.py"))
    syms = h["symbols"](kmap)
    mres = h["symbols"](mmap)
    stage = h["stage"]
    assert syms["kcore_root_fs_io_failure_v1538"] == 0o3761
    assert mres["exec_image_full_bounded_v1391"] == 0o3224
    assert mres["proc_pure_ram_restore_v1391"] == 0o2207
    full_pc = 0o32026 + 0o3224
    return_pc = 0o32026 + 0o433
    callback_pc = 0o32026 + 0o2333
    for offset, word in ((0o3224, "200000000004"),
                         (0o0432, "260740002207"),
                         (0o0433, "326040000451"),
                         (0o2333, "561400777774")):
        assert "IMAGE  %06o %s" % (offset, word) in dxr_dump
    assert "MEM                                  48 K" in trace
    assert "PURE                              LOADED" in trace
    assert "DTFS                              LOADED" in trace
    assert "aaaaaax[B" in trace
    assert "V1643_STAGE_B\n" in trace
    assert "ZV1643_STAGE_Z" in trace
    assert "HALT instruction, PC: 000000" in trace
    assert "HALT instruction, PC: 003776" not in trace
    for label in ("V1643_BOUNDED_FULL_SECONDARY",
                  "V1643_DTC3_DETACHED", "V1643_END_DTC3_DETACHED",
                  "V1643_FAILED_FULL_RETURN", "V1643_SAME_DTC3_REATTACHED",
                  "V1643_END_DTC3_REATTACHED", "V1643_LATER_FULL_CALLBACK"):
        assert trace.count(label + "\n") == 1, label
    assert "DTC3    147KW, not attached" in trace
    assert trace.index("V1643_END_FULL_PINNED\n") < trace.index(
        "V1643_DTC3_DETACHED\n")
    assert trace.index("V1643_END_DTC3_DETACHED\n") < trace.index(
        "V1643_FAILED_FULL_RETURN\n")
    assert trace.index("V1643_END_ROLLED_BACK\n") < trace.index(
        "V1643_SAME_DTC3_REATTACHED\n")
    assert trace.index("V1643_END_DTC3_REATTACHED\n") < trace.index(
        "V1643_LATER_FULL_CALLBACK\n")

    for fragment in ("#define P14_CHILDREN         6U",
                     "pid[i] = p14_spawn(rd, i != 0U);",
                     "denied = p14_spawn(rd, 1U);",
                     "p14_seed_secondary_v1643(void)",
                     "SYS_DTFS_TYPE_NATIVE) != 0",
                     "dsys_unmount(p14_mount_v1643)",
                     "SYS_MOUNT_RDONLY | SYS_DTFS_TYPE_NATIVE",
                     "p14_compressed_path[3]", "p14_source_v1643[3]",
                     "info.provider != 5UL || info.mount_id != 2UL",
                     "dsys_wait((unsigned int)pid[i], &status, 0U)",
                     "SYS_WAIT_STATUS_VALUE(status) != P14_STATUS",
                     "(void)p14_char('Z');"):
        assert fragment in source, "incorrect source-derived guest: " + fragment
    assert "F /SYSTEM/COMP " in manifest
    p, c = h["dxr_words"](plain), h["dxr_words"](compressed)
    assert p[0] == c[0] and p[2] == c[2]
    assert p[1] >> 18 == c[1] >> 18
    assert (p[1] & 0o300000) == 0o200000
    assert (c[1] & 0o300000) == 0o300000
    # Exact original vm_pdp6_pure_range_v1604.h formula: sector
    # boundary is rounded DOWN after user origin, not rounded up.
    # The enlarged secondary-source guest retains 006600 words.
    skip = ((c[2] >> 18) + 0o20) & ~0o177
    raw_words = 0o10000 - skip
    assert skip == 0o1200 and raw_words == 0o6600

    def capture(label):
        words, extents = stage(trace.replace("V1643_", "V1638_"),
                               syms, label)
        expected_slot = (0 if label in ("FULL_PINNED", "ROLLED_BACK",
                                        "LATER_FULL") else 1)
        assert words[syms["proc_current_slot"]] == expected_slot
        root = words[syms["vfs_namespace_root"]]
        assert root >> 24 == (7 << 6) | 1, \
            "selected namespace ROOT changed from TSFS mount 1"
        assert any(a == 0o130000 and b == 0o140000 and
                   kind == 1 and owner == 1 and pin == 0
                   for a, b, kind, pin, owner in extents)
        child = [(a, b, kind, pin, owner)
                 for a, b, kind, pin, owner in extents
                 if kind in (1, 4) and 2 <= owner <= 7]
        return words, child

    for label in ("B", "A"):
        words, owners = capture(label)
        assert len(owners) == 6
        assert {owner for a, b, kind, pin, owner in owners} == set(range(2, 8))
        assert all(kind == 4 and b - a == raw_words and pin == 0
                   for a, b, kind, pin, owner in owners)

    _, owners = capture("FULL_PINNED")
    dest = [(a, b, owner) for a, b, kind, pin, owner in owners
            if kind == 1 and pin == 1 and b - a == 0o10000]
    assert len(dest) == 1, "no separately pinned full target"
    slot = dest[0][2]
    assert slot in (3, 4, 5, 6, 7), "failed source must be compressed child"
    raw = [(a, b, pin) for a, b, kind, pin, owner in owners
           if kind == 4 and owner == slot]
    assert len(raw) == 1 and raw[0][2] == 1
    assert raw[0][1] - raw[0][0] == raw_words
    assert dest[0][1] <= raw[0][0] or raw[0][1] <= dest[0][0]
    assert re.search(r"Breakpoint, PC: %06o " % full_pc, trace)
    assert ("%o:\t200000000004" % full_pc) in trace

    _, after = capture("ROLLED_BACK")
    assert not any(kind == 1 and owner == slot
                   for a, b, kind, pin, owner in after), \
        "failed FULL destination still owned"
    assert [(a, b, pin) for a, b, kind, pin, owner in after
            if kind == 4 and owner == slot] == \
           [(raw[0][0], raw[0][1], 0)], \
           "failed source suffix was moved or retained a pin"
    assert all(pin == 0 for a, b, kind, pin, owner in after)
    assert re.search(r"Breakpoint, PC: %06o " % return_pc, trace)
    failed = trace.split("V1643_FAILED_FULL_RETURN\n", 1)[1].split(
        "V1643_STAGE_ROLLED_BACK\n", 1)[0]
    assert re.search(r"(?m)^1:\s*777777777774\s*$", failed), \
        "FULL loader did not report original -4 on real I/O failure"

    later = trace.split("V1643_LATER_FULL_CALLBACK\n", 1)[1].split(
        "V1643_STAGE_LATER_FULL\n", 1)[0]
    assert re.search(r"Breakpoint, PC: %06o " % callback_pc, trace)
    assert re.search(r"(?m)^1:\s*0+\s*$", later), \
        "no completed subsequent source-backed loader callback"
    _, next_owner = capture("LATER_FULL")
    pairs = [(a, b, kind, pin, owner) for a, b, kind, pin, owner
             in next_owner if pin == 1 and owner in range(3, 8)]
    assert len(pairs) == 2 and pairs[0][4] == pairs[1][4]
    assert {kind for a, b, kind, pin, owner in pairs} == {1, 4}
    assert not capture("Z")[1], "child PROCESS/PACKED leaked after WAITs"
    print("v1643: six genuine 48K PACKED owners backed by secondary DTFS")
    print("v1643: slot%o pinned RAW %06o..%06o and FULL %06o..%06o" %
          (slot, raw[0][0], raw[0][1], dest[0][0], dest[0][1]))
    print("v1643: real DTC3 failed read returned -4; source unpinned, target freed")
    print("v1643: same physical reel reattached, later FULL succeeded, six WAIT/HALT")
    print("PASS v1643: genuine recoverable secondary-backing FULL read failure")


def main():
    p = argparse.ArgumentParser()
    for name in ("kcore_map", "mres_map", "mres_dxr", "trace", "source",
                 "plain_dxr", "compressed_dxr", "manifest"):
        p.add_argument(name, type=Path)
    args = p.parse_args()
    names = ("kcore_map", "mres_map", "mres_dxr", "trace", "source",
             "plain_dxr", "compressed_dxr", "manifest")
    try:
        audit(*[(getattr(args, n).read_bytes() if i in (5, 6) else
                 getattr(args, n).read_text(encoding="ascii"))
                for i, n in enumerate(names)])
    except (AssertionError, ValueError, KeyError, UnicodeError) as exc:
        p.exit(1, "FAIL v1643 physical secondary FULL I/O: %s\n" % exc)


if __name__ == "__main__":
    main()
