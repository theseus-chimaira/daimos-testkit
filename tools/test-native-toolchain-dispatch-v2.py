#!/usr/bin/env python3
"""Bounded native-toolchain registry, fixture, and dispatch checks.

No guest, compiler, or simulator is executed. All subprocesses are mocked.
"""
import ast
import csv
import hashlib
import io
import contextlib
import importlib.util
from pathlib import Path
import subprocess
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location(
    "native_toolchain_runner", ROOT / "tools/run-native-toolchain-v1.py")
runner = importlib.util.module_from_spec(spec)
spec.loader.exec_module(runner)
rows = runner.entries()
assert len(rows) == 25
assert len({r["id"] for r in rows}) == len(rows)
assert all(r["status"] == "ready" and r["runner"] == "sh"
           and int(r["timeout"]) > 0 for r in rows)
manifest = list(csv.DictReader(
    (ROOT / "tests/validation/NATIVE-TOOLCHAIN-RETURN-20261119-v4.tsv").open(),
    delimiter="\t"))
assert len(manifest) == 71
assert len({r["new_path"] for r in manifest}) == 71
assert len({r["old_path"] for r in manifest}) == 71
for row in manifest:
    path = (ROOT / row["new_path"]).resolve()
    assert path.is_relative_to(ROOT) and path.is_file(), row
    body = path.read_bytes()
    if path.suffix in (".c", ".s"):
        assert hashlib.sha256(body).hexdigest() == row["original_sha256"], path
    elif path.suffix == ".sh":
        subprocess.run(["sh", "-n", str(path)], check=True)
    elif path.suffix == ".py":
        ast.parse(body.decode("utf-8"), filename=str(path))
for row in rows:
    assert any(m["new_path"] == row["path"] for m in manifest), row

calls = []

class Result:
    def __init__(self, code):
        self.returncode = code


def fake_run(args, cwd, env, timeout, check):
    assert cwd == ROOT and env["TMPDIR"] and not check
    assert args[0] == "sh" and Path(args[1]).is_file()
    assert timeout > 0
    calls.append(Path(args[1]).relative_to(ROOT).as_posix())
    return Result(1 if args[1].endswith(rows[0]["path"]) else 0)

with patch.object(runner.subprocess, "run", side_effect=fake_run), \
     contextlib.redirect_stdout(io.StringIO()):
    assert runner.main(["list"]) == 0
    assert not calls
    assert runner.main(["run", rows[1]["id"]]) == 0
    assert calls == [rows[1]["path"]]
    calls.clear()
    assert runner.main(["run-all"]) == 1
    assert calls == [r["path"] for r in rows]
    calls.clear()
    for args in (["run", "unknown"], ["run"], ["run", "bad", "more"]):
        try:
            runner.main(args)
        except SystemExit:
            pass
        else:
            raise AssertionError("accepted invalid selection %s" % args)
    assert not calls
print("native toolchain dispatch v2: PASS (25 suites, 71 fixtures; no guests)")
