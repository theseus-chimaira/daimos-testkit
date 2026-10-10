#!/usr/bin/env python3
"""Verify native KCC Makefile normalization preserves ordered graph/recipes."""
import sys
from pathlib import Path
from collections import defaultdict
if len(sys.argv) != 3:raise SystemExit('usage: checker OLD_DAIMOS_MK NEW_DAIMOS_MK')
def parse(path):
    deps=defaultdict(list); recipes=[]; special=[]
    for line in Path(path).read_text().splitlines():
        if line.startswith('\t'):recipes.append(line);continue
        if not line or line.startswith('#'):continue
        if ':' in line and '=' not in line.split(':',1)[0]:
            target,_,rhs=line.partition(':')
            deps[target].extend(rhs.split())
        else:special.append(line)
    return dict(deps),recipes,special
old=parse(sys.argv[1]);new=parse(sys.argv[2]);assert old==new, 'graph, recipe, or directive changed'
lines=Path(sys.argv[2]).read_text().splitlines()
assert max(map(len,lines))<=256, 'exceeds native MAKE line limit'
print('PASS: ordered prerequisites, all recipes, and directives preserved; lines=',len(lines))
