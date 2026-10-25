#!/usr/bin/env python3
"""Extract first before/after physical memory examines from SIMH output."""
import re
import sys

output, entry, publish, before, after = sys.argv[1:]
targets = {int(entry, 8): before, int(publish, 8): after}
current = None
records = {before: [], after: []}
with open(output, encoding="utf-8", errors="replace") as log:
    for line in log:
        found = re.search(r"Breakpoint, PC: ([0-7]+)", line)
        if found:
            pc = int(found.group(1), 8)
            current = targets.get(pc)
            continue
        if current and re.match(r"^\s*[0-7]{1,6}:\s*[0-7]{1,12}\b", line):
            records[current].append(line)
for name, lines in records.items():
    if len(lines) < 0o10000:
        raise SystemExit("insufficient memory records: %s (%d)" % (name, len(lines)))
    with open(name, "w", encoding="utf-8") as dest:
        dest.writelines(lines)
    print("snapshot: %s %d words" % (name, len(lines)))
