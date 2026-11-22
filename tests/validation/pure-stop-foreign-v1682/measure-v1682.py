#!/usr/bin/env python3
"""Original physical 48K STOP/foreign-TERM source-context oracle.

The accepted v1673 physical owner verifier still owns full A/B/C
conservation. This wrapper adds original STOPPED, WAIT and saved PC
checks before interpreting the foreign fatal event as valid.
"""
import importlib.util
import sys
from pathlib import Path


def main():
    if len(sys.argv) != 6:
        raise ValueError("usage: measure-v1682.py fixture.map kcore.map "
                         "original-console.clean 48 report.json")
    p = Path(__file__).parent.parent / "pure-runtime-reclaim-v1673" / \
        "measure-v1673.py"
    spec = importlib.util.spec_from_file_location("mm1673", p)
    old = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(old)
    content = Path(sys.argv[3]).read_text(encoding="ascii")
    for marker in ("V1682 STOP PID 2", "V1682 TERM PID 2",
                   "V1682 FOREIGN TERM ACCEPTED"):
        if content.count(marker) != 1:
            raise ValueError("missing or duplicate native source event: " +
                             marker)
    if "V1682 STOP FAILURE" in content or \
       "V1682 FOREIGN TERM REFUSED" in content:
        raise ValueError("native STOP/TERM source contract refused")
    views = old.observations(content, sys.argv[1])
    if len(views) != 3:
        raise ValueError("missing original physical A/B/C snapshots")
    words = views[1]["words"]
    addresses = {name: old.lookup(sys.argv[2], name)
                 for name in ("proc_table", "proc_high_slot",
                              "proc_storage_runtime_v29")}

    def physical(addr):
        if addr not in words:
            raise ValueError("missing source original physical %o" % addr)
        return words[addr]

    table = physical(addresses["proc_table"])
    meta = physical(table + 2 * 3)
    sched = physical(table + 2 * 3 + 2)
    mode_ptr = physical(addresses["proc_storage_runtime_v29"])
    mode = (physical(mode_ptr) >> 4) & 3
    state = (sched >> 33) & 7
    wait = (sched >> 18) & 0o60000
    if state != 6 or mode != 2 or wait != 0:
        raise ValueError("source STOP slot not packed/WAIT-free at B: "
                         "state=%d mode=%d wait=%o" % (state, mode, wait))
    uarea = (meta >> 18) & ((1 << 18) - 1)
    pc = physical(uarea + 0o20)
    if ((pc >> 18) & 0o10000) == 0:
        raise ValueError("STOP slot has executive, not USER, return PC")
    # The original v1673 oracle independently checks full MM/PROC and
    # native MEMINFO source consistency, B PACKED and C conservation.
    old.run(sys.argv)
    print("PASS v1682 original physical STOP slot 2: user-PC %012o, "
          "no private wait, RAW PACKED, safe foreign TERM" % pc)


if __name__ == "__main__":
    try:
        main()
    except (ValueError, OSError, UnicodeError) as exc:
        raise SystemExit("FAIL v1682 original STOP/TERM context: " + str(exc))
