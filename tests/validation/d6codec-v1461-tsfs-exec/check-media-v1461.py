#!/usr/bin/env python3
"""Validate fresh block TSFS media and reject the stale-codec fixture."""
import argparse
from pathlib import Path
import subprocess


def check(tool, path, expected):
    result = subprocess.run([str(tool), str(path)],
                            capture_output=True, text=True)
    if (result.returncode == 0) != expected:
        raise RuntimeError("unexpected checker result: " + str(path) +
                           " stdout=" + result.stdout +
                           " stderr=" + result.stderr)
    print("V1461_TSFS_MEDIA_PASS", "valid" if expected else "reject",
          path.name, flush=True)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--checker", required=True, type=Path)
    parser.add_argument("--valid", required=True, type=Path)
    parser.add_argument("--stale", required=True, type=Path)
    args = parser.parse_args()
    check(args.checker, args.valid, True)
    check(args.checker, args.stale, False)


if __name__ == "__main__":
    main()
