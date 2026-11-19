#!/usr/bin/env python3
"""Static checks for the native suite migration registry."""
import importlib.util
from pathlib import Path
from unittest.mock import patch

root = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location("native_dispatch", root / "tools/run-native-toolchain-v1.py")
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)
rows = module.entries()
assert len(rows) == 25
assert len(set(row["id"] for row in rows)) == len(rows)
assert all(row["status"] == "pending-migration" for row in rows)
with patch.object(module.subprocess, "run", side_effect=AssertionError("unexpected execution")):
    assert module.main(["list"]) == 0
    assert module.main(["run", rows[0]["id"]]) == 2
    assert module.main(["run-all"]) == 0
    try:
        module.main(["run", "missing-test"])
    except SystemExit:
        pass
    else:
        raise AssertionError("unknown test accepted")
print("native toolchain dispatcher v1: PASS (25 pending, no execution)")
