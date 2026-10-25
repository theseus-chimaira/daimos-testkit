#!/usr/bin/env python3
"""Analyze PDP-6 SIMH physical-memory snapshots without conflating live stack churn with corruption.

Usage: daimos-mm-swap-snapshot-invariants-v307.py simh.out
Works with the v297 snapshot fixture, whose breakpoints dump the physical
stack, process table, MM descriptors, and swap metadata. All addresses octal.
"""
import re
import sys


def fields(section):
    return {int(a, 8): int(v, 8) for a, v in re.findall(
        r"^([0-7]{1,6}):\s*([0-7]{12})$", section, re.M)}


def main():
    if len(sys.argv) != 2:
        raise SystemExit("usage: daimos-mm-swap-snapshot-invariants-v307.py simh.out")
    raw = open(sys.argv[1], encoding="utf-8", errors="replace").read()
    marks = list(re.finditer(r"Breakpoint, PC: 002623 ", raw))
    if not marks or "HALT instruction, PC:" not in raw:
        raise SystemExit("required swap-out and terminal snapshots absent")
    prior = fields(raw[marks[-1].end():].split("Breakpoint, PC:", 1)[0])
    after = fields(raw.split("HALT instruction, PC:", 1)[1])
    common = set(prior) & set(after)
    if not common:
        raise SystemExit("no matching physical snapshot words")
    changes = sorted(a for a in common if prior[a] != after[a])
    segments = {"idle-stack": (0o40350, 0o40450),
                "storage-map": (0o41141, 0o41145),
                "process-and-mm-metadata": (0o25024, 0o25220)}
    print("compared=%d changed=%d" % (len(common), len(changes)))
    for name, (lo, hi) in segments.items():
        sampled = [a for a in common if lo <= a < hi]
        changed = [a for a in changes if lo <= a < hi]
        print("%s: sampled=%d changed=%d" % (name, len(sampled), len(changed)))
        if name == "storage-map" and sampled and changed:
            print("WARNING: storage-mode map changed; correlate with legitimate transitions")
        if name == "idle-stack" and changed:
            print("NOTE: stack changes are expected during nested execution; not proof of overflow")
    for addr in (0o24722, 0o24772, 0o41141):
        if addr in common:
            print("%06o: %012o -> %012o" % (addr, prior[addr], after[addr]))
    if 0o41141 in common and prior[0o41141] == after[0o41141]:
        print("storage-map first word unchanged")
    # Reject missing evidence rather than suggesting memory integrity.
    if not any(lo <= a < hi for a in common for lo, hi in segments.values()):
        raise SystemExit("no relevant memory ranges in snapshot")


if __name__ == "__main__":
    main()
