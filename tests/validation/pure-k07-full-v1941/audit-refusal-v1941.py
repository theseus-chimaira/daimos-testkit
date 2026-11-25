#!/usr/bin/env python3
"""Audit the interrupted old six-child workload, NOT a valid B snapshot."""
import argparse
from pathlib import Path
import runpy

v = runpy.run_path(str(Path(__file__).with_name("verify-v1941.py")))


def audit(build, work):
    s = v["symbols"](build / "kcore.map")
    m = v["symbols"](build / "pure-mres-v1612.map")
    trace = (work / "physical.clean").read_text(encoding="ascii")
    assert "aaaaa!r" in trace and "aaaaaax[B" not in trace
    assert "Simulation stopped, PC:" in trace
    d = v["words"](v["section"](trace, "B"))
    ext = v["extents"](d, s)
    assert d[s["proc_current_slot"]] == 0
    assert d[s["proc_exec_resv_head_v1933"]] == 0
    assert d[s["proc_high_slot"]] == 7
    assert d[s["mm_extent_count"]] == 17
    assert d[s["mm_extent_capacity"]] == 32
    packed = [e for e in ext if e[2] == 4]
    assert len(packed) == 5 and {e[4] for e in packed} == set(range(2, 7))
    assert all(e[1]-e[0] == 0o7000 and e[3] == 0
               for e in packed if e[4] != 2)
    assert [e for e in packed if e[4] == 2] == [
        (0o120000, 0o130000, 4, 1, 2)]
    assert all(not (e[2] == 3 and e[4] == 0o1007) for e in ext)
    assert all(not (e[2] in (1, 4) and e[4] in (1, 7)) for e in ext)
    # The top APR is free AFTER the parent's failure exit. The snapshot
    # cannot establish the precise preceding RUN allocation failure.
    assert not any(e[1] > 0o130000 for e in ext)
    service = d[s["proc_swap_service_one"]]
    reclaim = d[s["proc_swap_reclaim"]]
    assert service >> 18 == reclaim >> 18 == 0o254000
    base = (service & 0o777777) - m["proc_pure_mres_service_v1612"]
    assert (reclaim & 0o777777) == base+m["proc_pure_mres_reclaim_v1612"]
    print("PASS diagnostic: five admissions, sixth RUN refusal")
    print("PASS diagnostic: four retained 07000 PACKED extents, pinned 010000 slot2")
    print("PASS diagnostic: empty loader reservation list; no slot7 VM/u-area")
    print("Derived loaded PURE base %06o, FULL entry candidate %06o" %
          (base, base+m["exec_image_full_bounded_v1391"]))
    print("Post-failure slot0 snapshot; no pre-RUN NOMEM or FULL acceptance claim")


if __name__ == "__main__":
    p = argparse.ArgumentParser()
    p.add_argument("build", type=Path)
    p.add_argument("work", type=Path)
    a = p.parse_args()
    audit(a.build, a.work)
