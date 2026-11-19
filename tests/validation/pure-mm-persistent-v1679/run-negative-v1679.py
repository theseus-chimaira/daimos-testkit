#!/usr/bin/env python3
"""Verify two repeated original RUN milestones, then v1678 MM negatives."""
from pathlib import Path
import subprocess
import sys


def main():
    if len(sys.argv) != 7:
        raise ValueError("usage: run-negative-v1679.py console.clean "
                         "fixture.map kcore.map accepted.json workdir variant")
    console, fixture, coremap, accepted, workdir, variant = sys.argv[1:]
    work = Path(workdir)
    work.mkdir(parents=True, exist_ok=True)
    source = Path(console).read_text(encoding="ascii")
    for attempt in range(2):
        marker = "V1679 REPEAT REFUSED %d" % attempt
        if source.count(marker) != 1:
            raise ValueError("missing original " + marker)
        corrupted = work / (variant + "-missing-repeat-%d.clean" % attempt)
        corrupted.write_text(source.replace(marker, "V1679 LOST REFUSAL %d" %
                                           attempt, 1), encoding="ascii")
        cmd = [sys.executable, str(Path(__file__).with_name(
               "measure-v1679.py")), fixture, coremap, str(corrupted),
               "48", str(work / ("corrupted-%d.json" % attempt))]
        result = subprocess.run(cmd, text=True, capture_output=True)
        if result.returncode == 0 or "FAIL v1679 repeated physical MM oracle" \
                not in result.stderr:
            raise ValueError("unsafe repeated original RUN accepted")
        print("PASS v1679: missing original repeated refusal %d rejected" %
              attempt)
    original = Path(__file__).parent.parent / "pure-mm-precommit-v1678" / \
               "run-negative-v1678.py"
    subprocess.run([sys.executable, str(original), console, fixture,
                    coremap, accepted, str(work / "original-mm"), variant],
                   check=True)


if __name__ == "__main__":
    try:
        main()
    except (OSError, ValueError, subprocess.CalledProcessError) as exc:
        raise SystemExit("FAIL v1679 repeated MM negative suite: " + str(exc))
