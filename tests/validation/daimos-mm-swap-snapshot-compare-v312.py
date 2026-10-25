#!/usr/bin/env python3
"""Compare SIMH physical RAM snapshots from swap-out entry to pre-publication (v312)."""
import re
import sys


def read_snapshot(path):
    memory = {}
    # SIMH text examines use octal address/word pairs.
    with open(path, encoding="utf-8", errors="replace") as stream:
        for line in stream:
            match = re.match(r"^\s*([0-7]{1,6}):\s*([0-7]{1,12})\b", line)
            if match:
                memory[int(match.group(1), 8)] = int(match.group(2), 8)
    if not memory:
        raise ValueError("no octal address/word records in " + path)
    return memory


def symbols(path):
    found = {}
    with open(path, encoding="utf-8") as stream:
        for line in stream:
            fields = line.split()
            if len(fields) >= 2 and re.fullmatch(r"[0-7]+", fields[1]):
                found[fields[0]] = int(fields[1], 8)
    return found


def main():
    old, new = (read_snapshot(path) for path in sys.argv[1:3])
    syms = symbols(sys.argv[3])
    required = ("mm_extents", "mm_extent_count", "proc_swap_records",
                "proc_storage_runtime_v29", "mach_kernel_stack_base")
    for name in required:
        if name not in syms:
            raise ValueError("missing map symbol " + name)
    shared = old.keys() & new.keys()
    changed = sorted(a for a in shared if old[a] != new[a])
    print("captured: before=%d words after=%d words common=%d changed=%d" %
          (len(old), len(new), len(shared), len(changed)))
    print("unmatched addresses: before=%d after=%d" %
          (len(old.keys() - shared), len(new.keys() - shared)))
    for name in required:
        addr = syms[name]
        print("%-27s %06o: %012o -> %012o" %
              (name, addr, old.get(addr, 0), new.get(addr, 0)))
    # Report changes by architectural purpose, not arbitrary dump offsets.
    regions = [
        ("register / low memory", 0, 0o60),
        ("KCORE code and permanent data", 0o60, syms["mm_extents"]),
        ("MM descriptor table", syms["mm_extents"], syms["mm_extents"] + 272),
        ("remaining physical RAM", syms["mm_extents"] + 272, 0o1000000),
    ]
    for label, start, end in regions:
        addresses = [a for a in changed if start <= a < end]
        print("%-31s changed=%d" % (label, len(addresses)))
        for addr in addresses[:12]:
            print("  %06o: %012o -> %012o" % (addr, old[addr], new[addr]))
    if len(shared) != 0o1000000 or old.keys() != new.keys():
        raise ValueError("expected equal complete 256K-word snapshots")
    if len(shared) < 0o10000:
        raise ValueError("snapshot too sparse for meaningful comparison")


if __name__ == "__main__":
    if len(sys.argv) != 4:
        sys.exit("usage: snapshot-compare before after kcore.map")
    main()
