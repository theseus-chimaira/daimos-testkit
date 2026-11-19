#!/usr/bin/env python3
"""Repeated native RUN refusal + original v1678 physical MM oracle."""
import importlib.util
import sys
from pathlib import Path


def main():
    if len(sys.argv) != 6:
        raise ValueError("usage: measure-v1679.py fixture.map kcore.map "
                         "console.clean 48 report.json")
    console = Path(sys.argv[3]).read_text(encoding="ascii")
    for attempt in range(2):
        for kind in ("RUN", "REFUSED"):
            marker = "V1679 REPEAT %s %d" % (kind, attempt)
            if console.count(marker) != 1:
                raise ValueError("missing/duplicated original repeated "
                                 "RUN/REFUSED milestone " + marker)
    if "V1679 UNEXPECTED REPEAT ADMISSION" in console:
        raise ValueError("a repeated pressure RUN was admitted")
    previous = (Path(__file__).parent.parent / "pure-mm-precommit-v1678" /
                "measure-v1678.py")
    spec = importlib.util.spec_from_file_location("measure1678", previous)
    old = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(old)
    old.run(sys.argv)
    print("PASS v1679: original physical MM 8 PACKED + 1 RESIDENT and "
          "two extra genuine refused RUNs")


if __name__ == "__main__":
    try:
        main()
    except (OSError, ValueError) as exc:
        raise SystemExit("FAIL v1679 repeated physical MM oracle: " + str(exc))
