#!/usr/bin/env python3
"""Verify that $@/$< substitutions preserve native KCC DAS commands."""
from pathlib import Path
import sys
if len(sys.argv) != 3:
    raise SystemExit('usage: checker BEFORE_DAIMOS_MK AFTER_DAIMOS_MK')
def commands(name):
    target = ''; first = ''; result = []; graph = []
    for line in Path(name).read_text().splitlines():
        if line and line[0] not in ' \t#' and ':' in line and '=' not in line.split(':', 1)[0]:
            t, rhs = line.split(':', 1)
            target = t
            items = rhs.replace('\\', ' ').split()
            first = items[0] if items else ''
            graph.append((target, tuple(items)))
        if line.startswith('\t'):
            result.append(line.replace('$@', target).replace('$<', first))
    return result, graph
before, after = commands(sys.argv[1]), commands(sys.argv[2])
assert before == after, 'expanded commands or prerequisite declarations differ'
print('PASS: unchanged expanded commands:', len(before[0]), 'and rules:', len(before[1]))
