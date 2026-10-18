#!/usr/bin/env python3
"""Adapt a generated SIMH DTC boot.ini to AAP-comparable hardware.

Usage: daimos-simh-aap-hardware-v24.py INPUT_INI OUTPUT_INI
The output deliberately omits SIMH's trailing exit command so a
diagnostic interrupt can reach the SIMH command prompt.
"""

from pathlib import Path
import shlex
import sys


def main():
    if len(sys.argv) != 3:
        sys.exit("usage: daimos-simh-aap-hardware-v24.py INPUT_INI OUTPUT_INI")
    source = Path(sys.argv[1])
    target = Path(sys.argv[2])
    absent = {"cr", "cp", "lpt", "dsk", "dp", "dr", "mtc",
              "dcs", "ge", "slave"}
    output = []
    disabled = set()
    for line in source.read_text().splitlines():
        parts = shlex.split(line, comments=False)
        if parts and parts[0].lower() == "set" and len(parts) > 1:
            name = parts[1].lower()
            if name in absent:
                if name not in disabled:
                    output.append("set " + name + " disabled")
                    disabled.add(name)
                continue
            if (name.startswith(("dr", "mtc", "dcs", "ge"))
                    and name not in ("dct", "dtc")):
                continue
        if parts and parts[0].lower() == "attach":
            unit = next((x.lower() for x in parts[1:]
                         if not x.startswith("-")), "")
            if unit.startswith(("cp", "lpt", "dsk", "dr",
                                "mtc", "dcs", "ge", "cr")):
                continue
        if parts and parts[0].lower() == "exit":
            continue
        output.append(line)
    target.write_text("\n".join(output) + "\n")


if __name__ == "__main__":
    main()
