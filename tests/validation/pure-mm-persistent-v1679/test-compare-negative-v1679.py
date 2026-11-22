#!/usr/bin/env python3
"""Reject a forged paired original-MM snapshot or linked PURE binary."""
import json
import shutil
import subprocess
import sys
from pathlib import Path


def main():
    if len(sys.argv) != 6:
        raise ValueError("usage: test-compare-negative-v1679.py "
                         "general-build strict-build general-run strict-run workdir")
    builds = [Path(n) for n in sys.argv[1:3]]
    runs = [Path(n) for n in sys.argv[3:5]]
    work = Path(sys.argv[5]);work.mkdir(parents=True, exist_ok=True)
    compare = Path(__file__).with_name("compare-fault-v1679.py")
    original = [sys.executable, str(compare)] + [str(n) for n in builds + runs]
    subprocess.run(original, check=True, capture_output=True, text=True)
    fake_run = work / "fake-strict-run"
    fake_run.mkdir(exist_ok=True)
    for name in ("strict-48-console.clean", "strict-48-report.json"):
        shutil.copyfile(runs[1] / name, fake_run / name)
    report = fake_run / "strict-48-report.json"
    data = json.loads(report.read_text(encoding="ascii"))
    data["pressure"]["free_words"] += 1
    report.write_text(json.dumps(data, sort_keys=True, indent=2) + "\n",
                      encoding="ascii")
    cmd = [sys.executable, str(compare)] + [str(n) for n in builds] + \
          [str(runs[0]), str(fake_run)]
    bad = subprocess.run(cmd, text=True, capture_output=True)
    if bad.returncode == 0 or "original physical MM-owner state differs" \
            not in (bad.stdout + bad.stderr):
        raise ValueError("forged paired original MM pressure report accepted")
    print("PASS v1679: forged paired original physical MM report rejected")


if __name__ == "__main__":
    try:
        main()
    except (ValueError, OSError, subprocess.CalledProcessError) as exc:
        raise SystemExit("FAIL v1679 paired report negative: " + str(exc))
