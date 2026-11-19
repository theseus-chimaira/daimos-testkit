#!/usr/bin/env python3
"""Audit the actual 48K PDP-6 PURE prefix transaction entry.

Never confuse a COMMIT call with a completed MM retype or pin release.
Physical samples are checked against the exact linked KCORE/PURE DXRs.
"""
import re
import subprocess
import sys
from pathlib import Path


def symbols(path):
    result = {}
    for line in Path(path).read_text().splitlines():
        fields = line.split()
        if len(fields) >= 2 and not fields[1].strip("01234567"):
            result[fields[0]] = int(fields[1], 8)
    return result


def core_values(text):
    values = {}
    for addr, word in re.findall(
            r"(?m)(?<![0-7])([0-7]{1,7}):\s*([0-7]{1,12})(?=\s|$)",
            text):
        key = int(addr, 8)
        value = int(word, 8)
        if key in values and values[key] != value:
            raise ValueError("changing physical value at %06o in snapshot" %
                             key)
        values[key] = value
    return values


def image_words(path, tool):
    output = subprocess.check_output([tool, "-d", path], text=True)
    return {int(a, 8): int(v, 8) for a, v in re.findall(
        r"(?m)^IMAGE\s+([0-7]{6})\s+([0-7]{12})$", output)}


def audit(kmap, pmap, pdxr, trace, tool):
    kernel = symbols(kmap)
    pure = symbols(pmap)
    for name, offset in (
            ("mm_pure_release_prefix_v1384", 0o2563),
            ("mm_pure_commit_prefix_v1384", 0o2565)):
        if pure.get(name) != offset:
            raise ValueError("original PURE MM transaction label moved")
    image = image_words(pdxr, tool)
    if (image.get(0o2563) != 0o201000000001 or
            image.get(0o2565) != 0o201000000002):
        raise ValueError("PURE MM release/commit instruction bytes moved")
    if (0o32027 + pure["mm_pure_commit_prefix_v1384"] != 0o34614 or
            0o32027 + pure["mm_pure_release_prefix_v1384"] != 0o34612):
        raise ValueError("PURE MRES relocated away from physical guest")

    text = Path(trace).read_text()
    if ("PURE" not in text or "LOADED" not in text or
            "<010000+020000>" not in text):
        raise ValueError("not an opt-in PURE 48K physical guest")
    match = re.search(r"Breakpoint, PC: 034614 \([^\n]*\)\n", text)
    if not match:
        raise ValueError("original MM commit function was not entered")
    earlier = text[:match.start()]
    if "Breakpoint, PC: 034612 " in earlier:
        raise ValueError("rollback reached before first commit")
    next_bp = re.search(r"Breakpoint, PC:", text[match.end():])
    end = match.end() + next_bp.start() if next_bp else len(text)
    state = core_values(text[match.end():end])

    for reg, value in ((1, 0o116000), (2, 2),
                       (3, 0o1000), (4, 0o10000)):
        if state.get(reg) != value:
            raise ValueError("unexpected physical commit AC%o" % reg)
    for name, value in (("proc_current_slot", 0),
                        ("proc_sched_cursor", 2),
                        ("mm_extent_count", 0o17)):
        address = kernel.get(name)
        if address is None or state.get(address) != value:
            raise ValueError("unexpected transaction owner " + name)

    mm = kernel.get("mm_extents")
    if mm is None or mm != 0o24254:
        raise ValueError("original KCORE MM descriptor location moved")
    i = 13
    if state.get(mm + 2 * i) != 0o10000116000:
        raise ValueError("PACKED owner 2 not at physical APR 116000")
    if state.get(mm + 2 * i + 1) != 0o14000002:
        raise ValueError("owner 2 must be PACKED with exactly one pin")
    for offset, expected in (
            (20, (0o7000 << 18) | 0o67000),
            (21, 0o4000005),
            (22, (0o7000 << 18) | 0o77000),
            (23, 0o4000004),
            (24, (0o7000 << 18) | 0o107000),
            (25, 0o4000003)):
        if state.get(mm + offset) != expected:
            raise ValueError("other PACKED suffix changed at %06o" %
                             (mm + offset))
    print("PASS v1620 physical original PURE MM COMMIT entry at 034614")
    print("PASS v1620 slot 2: base 116000, prefix 001000, APR 010000")
    print("PASS v1620 slot 2 pre-commit: full PACKED, exactly one pin")
    print("PASS v1620 three other sleeping RAW suffixes remain unpinned")
    print("OPEN v1620: retype execution, pin release, READY_ONCE and RUN")


def main():
    if len(sys.argv) != 6:
        raise ValueError(
            "usage: audit-v1620.py KCORE.map PURE.map PURE.dxr "
            "TRACE.clean DXRCHECK")
    audit(*sys.argv[1:])


if __name__ == "__main__":
    try:
        main()
    except (ValueError, OSError, subprocess.CalledProcessError) as exc:
        raise SystemExit("FAIL v1620 physical MM audit: " + str(exc))
