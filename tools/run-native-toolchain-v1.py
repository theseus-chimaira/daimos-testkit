#!/usr/bin/env python3
"""Explicit DAIMOS guest-native toolchain test dispatcher.

The registry is local to daimos-testkit. No guest tests run by default.
"""
import csv
import os
from pathlib import Path
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[1]
REGISTRY = ROOT / "tests/validation/NATIVE-TOOLCHAIN-TESTS-v1.tsv"


def entries():
    with REGISTRY.open(encoding="ascii", newline="") as stream:
        return list(csv.DictReader(stream, delimiter="\t"))


def main(args):
    if not args or args[0] not in ("list", "run", "run-all"):
        raise SystemExit("usage: run-native-toolchain-v1.py list | run ID | run-all")
    rows = entries()
    ids = [row["id"] for row in rows]
    if len(ids) != len(set(ids)):
        raise SystemExit("duplicate native test IDs")
    if args == ["list"]:
        for row in rows:
            print("%s\t%s\t%s" % (row["id"], row["status"], row["path"]))
        return 0
    if len(args) == 2 and args[0] == "run":
        chosen = [row for row in rows if row["id"] == args[1]]
        if len(chosen) != 1:
            raise SystemExit("unknown native test: " + args[1])
    elif args == ["run-all"]:
        chosen = rows
    else:
        raise SystemExit("usage: run-native-toolchain-v1.py list | run ID | run-all")
    failures = 0
    for row in chosen:
        if row["status"] != "ready":
            print("SKIP %s: migration not complete" % row["id"], flush=True)
            if args[0] == "run":
                return 2
            continue
        path = (ROOT / row["path"]).resolve()
        if not path.is_relative_to(ROOT.resolve()) or not path.is_file():
            print("ERROR %s: missing/unsafe test path" % row["id"], flush=True)
            failures += 1
            continue
        if row["runner"] not in ("sh", "python3"):
            print("ERROR %s: invalid runner" % row["id"], flush=True)
            failures += 1
            continue
        try:
            timeout = int(row["timeout"])
            if timeout <= 0:
                raise ValueError("nonpositive timeout")
            result = subprocess.run([row["runner"], str(path)], cwd=ROOT,
                                    env=dict(os.environ, TMPDIR=os.environ.get(
                                        "TMPDIR") or str(Path.home() / "tmp")),
                                    timeout=timeout, check=False)
            if result.returncode:
                failures += 1
                print("FAIL %s (exit %d)" % (row["id"], result.returncode), flush=True)
        except (ValueError, subprocess.TimeoutExpired) as error:
            failures += 1
            print("FAIL %s: %s" % (row["id"], error), flush=True)
    return 1 if failures else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
