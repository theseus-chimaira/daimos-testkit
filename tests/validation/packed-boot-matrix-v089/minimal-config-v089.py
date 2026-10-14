#!/usr/bin/env python3
"""Derive a fail-closed PDP-6 minimal-device SIMH configuration.

Keep CPU, CTY (built into PDP-6), PCLK, and bootstrap PTR; beyond these,
allow only the requested disk or DECtape controller and attached units.
Other devices are not enabled, attached, or configured.  Full profiles use
the unmodified image builder's simulator configuration.
"""
import pathlib
import re
import sys


def convert(source: str, kind: str) -> str:
    if kind not in ("d6fs", "tsfs"):
        raise ValueError("invalid minimal hardware profile")
    allowed = {"pclk", "ptr", "dsk", "dct"} if kind == "d6fs" else {
        "pclk", "ptr", "dct", "dtc", "dtc0", "dtc1"
    }
    media = {"ptr", "dsk0"} if kind == "d6fs" else {
        "ptr", "dtc0", "dtc1"
    }
    # SIMH enables some controllers by default.  Explicitly disable every
    # unused controller rather than merely dropping its configuration line.
    controllers = (
        "cr", "cp", "ptp", "lpt", "dsk", "dp", "dr", "dct",
        "dtc", "mtc", "dcs", "ge", "slave", "dpy", "wcnsls",
        "ocnsls"
    )
    lines = [f"set {dev} disabled" for dev in controllers if dev not in allowed]
    for line in source.splitlines():
        words = line.strip().split()
        if len(words) >= 3 and words[0] == "set" and words[1] != "cpu":
            if words[1].lower() not in allowed:
                continue
        if len(words) >= 3 and words[0] == "attach":
            dev = next((w for w in words[1:] if not w.startswith("-") ), "").lower()
            if dev not in media:
                continue
        if words[:2] == ["deposit", "ptr"] and "ptr" not in allowed:
            continue
        lines.append(line)
    output = "\n".join(lines) + "\n"
    if "set cpu 32k" not in output:
        raise ValueError("a minimal configuration must have exactly 32K memory")
    required = ["attach -q ptr", "go 020"]
    if kind == "d6fs":
        required.append("attach -q dsk0")
    else:
        required.extend(("attach -q dtc0", "attach -q dtc1"))
    if not all(item in output for item in required):
        raise ValueError("boot media or bootstrap is missing")
    for line in output.splitlines():
        match = re.match(r"^(set|attach)\s+(?:-\S+\s+)*([^\s]+)", line)
        if match and match.group(2).lower() not in allowed | media | {"cpu"}:
            if match.group(1) == "set" and line.endswith(" disabled"):
                continue
            raise ValueError(f"unexpected peripheral: {line}")
    return output


if __name__ == "__main__":
    if len(sys.argv) != 4:
        sys.exit("usage: minimal-config-v089.py d6fs|tsfs full.ini minimal.ini")
    pathlib.Path(sys.argv[3]).write_text(convert(pathlib.Path(sys.argv[2]).read_text(), sys.argv[1]))
