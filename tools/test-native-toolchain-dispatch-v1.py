#!/usr/bin/env python3
"""Check native-suite registry selection without launching guest tests."""
import importlib.util
from pathlib import Path
from unittest.mock import patch

root = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location(
    "native_dispatch", root / "tools/run-native-toolchain-v1.py")
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)
rows = module.entries()
assert len(rows) == 25
assert len({row["id"] for row in rows}) == len(rows)
assert all(row["status"] in ("ready", "pending-migration") for row in rows)
with patch.object(module.subprocess, "run", side_effect=AssertionError("unexpected execution")):
    assert module.main(["list"]) == 0
    for name in ("missing-test", "", "../unknown"):
        try:
            module.main(["run", name])
        except SystemExit:
            pass
        else:
            raise AssertionError("unknown test accepted: " + name)
print("native toolchain dispatcher v1: PASS (25 known IDs; no execution)")
