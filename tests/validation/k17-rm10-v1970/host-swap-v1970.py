#!/usr/bin/env python3
"""Real KA10 RM10-backed swap, original six-child v1955 oracle."""
import json
from pathlib import Path
import runpy
import sys

HERE = Path(__file__).resolve().parent
S = runpy.run_path(str(HERE.parent/"disk-swap-k09-v1955/host-v1955.py"))
V = runpy.run_path(str(HERE.parent/"disk-swap-k09-v1955/verify-v1955.py"))


def snapshot(token, coremap, core, read, read_range):
    S["extra_snapshot"](token, coremap, core, read, read_range)
    for n in ("mfsdev_drm_reads", "mfsdev_drm_writes", "drm236_active_request",
              "device_region_map", "backing_region_count"):
        read(S["V"]["source_symbol"](coremap,n))
    read(S["V"]["source_symbol"](coremap,"mfsdev_storage_errors")+5)
    read_range(0o152,2,core)


S["V"]["run"](sys.argv,extra_snapshot=snapshot)
report=V["verify"](Path(sys.argv[4]),Path(sys.argv[5]).with_suffix(".clean").read_text(),
                   provider="drum")
assert all(r["errors"]==0 for r in report.values())
assert report["A"]["writes"]==0
assert report["B"]["writes"]-report["A"]["writes"]==report["B"]["bitmap_used"]
assert report["C"]["reads"]-report["B"]["reads"]==report["B"]["bitmap_used"]
assert report["C"]["writes"]==report["B"]["writes"]
Path(sys.argv[5]).with_name("report.json").write_text(json.dumps(report,indent=2)+"\n")
print("PASS native KA10 RM10 backing, exact canaries/WAIT and MM cleanup")
for p,r in report.items():
    print(p,"MM",r["extents"],"free",r["free"],"bitmap",r["bitmap_used"],
          "drum reads/writes",r["reads"],r["writes"])
