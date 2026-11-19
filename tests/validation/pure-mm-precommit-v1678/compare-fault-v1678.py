#!/usr/bin/env python3
"""Paired real PDP-6 physical owner-state acceptance for one MRES fault.

Run only after both independent source-linked 48K original v1673-parser-backed v1678
physical-state oracles and v1678 counter/negative cases have passed.
This deliberately does not claim original MM write-watch high-water.
"""
import json
import sys
from pathlib import Path


def main():
    if len(sys.argv) != 5:
        raise ValueError("usage: compare-fault-v1678.py "
                         "general-build strict-build general-run strict-run")
    builds = [Path(s) for s in sys.argv[1:3]]
    runs = [Path(s) for s in sys.argv[3:5]]
    for name in ("kcore.dxr", "pure-mres-v1612.dxr", "kcore.map",
                 "pure-mres-v1612.map"):
        a = (builds[0] / name).read_bytes()
        b = (builds[1] / name).read_bytes()
        if a != b:
            raise ValueError("different paired original binaries: " + name)
    reports = []
    for v, run in zip(("general", "strict"), runs):
        s = (run / (v + "-48-console.clean")).read_text(
            encoding="ascii")
        if "V1673 PASS RUN EXIT WAIT" not in s:
            raise ValueError(v + " guest did not complete real WAIT")
        report = json.loads((run / (v + "-48-report.json")).read_text(
            encoding="ascii"))
        reports.append(report)
    if reports[0] != reports[1]:
        raise ValueError("original physical MM-owner state differs")
    print("PASS v1678: general/strict original 48K MM-owner reports and "
          "source-linked fixed KCORE/PURE MRES are identical")


if __name__ == "__main__":
    try:
        main()
    except (ValueError, KeyError, OSError) as exc:
        raise SystemExit("FAIL v1678 paired physical fault: " + str(exc))
