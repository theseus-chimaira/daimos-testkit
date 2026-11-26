#!/usr/bin/env python3
"""Monitor marker parsing, including actual seed-run flush diagnostic."""
import argparse
from pathlib import Path
import runpy

p=argparse.ArgumentParser()
p.add_argument("seed_trace", type=Path)
a=p.parse_args()
mark=runpy.run_path(str(Path(__file__).with_name("replay-v1943.py")))["guest_marker"]
actual=a.seed_trace.read_text(encoding="ascii")
assert "ijkccccccccdsuIEDTC3: writing buffer to file:" in actual
assert mark(actual,"IE","E")
assert mark("IEV1943_STAGE_E\n","IE","E")
assert not mark("I\nSimulation stopped, PC: 032077\nV1943_STAGE_E\n","IE","E")
assert not mark("IE\nSimulation stopped, PC: 032077\nV1943_STAGE_E\n","IE","E")
assert not mark("IEDTC3: writing buffer to file: reel\nSimulation stopped, PC: 032077\nV1943_STAGE_E\n","IE","E")
print("PASS actual flush marker and three missing/interrupt marker negatives")
