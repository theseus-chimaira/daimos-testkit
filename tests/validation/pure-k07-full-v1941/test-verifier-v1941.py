#!/usr/bin/env python3
"""Unit tests of physical verifier's geometry predicate only."""
from pathlib import Path
import runpy

check = runpy.run_path(str(Path(__file__).with_name(
    "verify-v1941.py")))["check_full"]
ac = {1: 0o1000001, 2: 0o120000, 3: 0o60000, 4: 0o10000}
src = (0o111000, 0o120000, 4, 1, 3)
dst = (0o120000, 0o130000, 1, 1, 3)
u = (0o60000, 0o60410, 3, 0, 0o1003)
earlier = [(src[0], src[1], 4, 0, 3)]
assert check(ac, [src, dst, u], earlier) == (3, src, dst)
cases = [
    ([src, (*dst[:3], 0, 3), u], earlier),
    ([(*src[:3], 0, 3), dst, u], earlier),
    ([src, (*dst[:4], 2), u], earlier),
    ([(0o113000, 0o122000, 4, 1, 3), dst, u], earlier),
    ([src, dst, (*u[:4], 0o1004)], earlier),
    ([src, dst, u], []),
    ([src, (dst[0], dst[1]-1, 1, 1, 3), u], earlier),
]
for i, (ext, before) in enumerate(cases, 1):
    try:
        check(ac, ext, before)
    except AssertionError:
        print("PASS verifier negative %d" % i)
    else:
        raise SystemExit("unsafe geometry accepted: %d" % i)
print("PASS v1941 verifier predicate: 1 synthetic positive, 7 negatives")
