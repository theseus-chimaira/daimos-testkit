#!/usr/bin/env python3
"""v1652: source-derived 64K nine-child secondary-DTFS PURE workload.

Only the original user test's array and process count changes.
The real parent FD map, syscalls, immutable compressed child,
private data checks and exact WAIT contract remain unchanged.
No kernel code, MM descriptor or BStore record is manipulated.
"""

from pathlib import Path
import runpy
import sys


def generate(source):
    here = Path(__file__).resolve().parent
    original = runpy.run_path(str(here.parent /
        "pure-secondary-read-v1643/prepare-v1643.py"))
    guest = original["generate"](source)
    before = "#define P14_CHILDREN         6U"
    after = "#define P14_CHILDREN         9U"
    assert guest.count(before) == 1
    guest = guest.replace(before, after, 1)
    assert guest.count("pid[i] = p14_spawn(rd, i != 0U);") == 1
    assert guest.count("denied = p14_spawn(rd, 1U);") == 1
    assert guest.count("dsys_wait((unsigned int)pid[i], &status, 0U)") == 1
    assert guest.count("SYS_WAIT_STATUS_VALUE(status) != P14_STATUS") == 1
    assert guest.count("p14_seed_secondary_v1643(void)") == 1
    return guest


if __name__ == "__main__":
    if len(sys.argv) != 3:
        raise SystemExit("usage: prepare-v1652.py original-v1614.c output-v1652.c")
    source = Path(sys.argv[1]).read_text(encoding="ascii")
    Path(sys.argv[2]).write_text(generate(source), encoding="ascii")
    print("v1652: source-matched 9-child 64K compressed secondary PURE guest")
