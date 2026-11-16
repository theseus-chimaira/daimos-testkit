#!/usr/bin/env python3
"""Refuse to credit a BRK fit as RAW reclamation without memory evidence.

The original v1614 PIPE/WAIT test is compiled with a smaller final BRK
target. Successful BRK alone does not establish that any owner was packed.
"""
import re
import sys
from pathlib import Path


def audit(source_path, trace_path):
    source = Path(source_path).read_text()
    count = re.search(r"#define P14_CHILDREN\s+([0-9]+)U", source)
    target = re.search(r"#define P14_BRK_TARGET\s+(0[0-7]+)UL", source)
    if not count or not target or target.group(1) != "016000":
        raise ValueError("not the source-controlled fitting BRK variant")
    children = int(count.group(1))
    if children not in (4, 6):
        raise ValueError("only four/six-child fixtures are supported")
    trace = Path(trace_path).read_text().replace("\r", "")
    if children == 6:
        if "PURE" not in trace or "LOADED" not in trace:
            raise ValueError("physical guest did not install PURE MRES")
        if "aaaaa!c" not in trace:
            raise ValueError("five valid children plus sixth refusal missing")
        if re.search(r"<[0-7]{6}\+[0-7]{6}>", trace):
            raise ValueError("six-child case incorrectly reached BRK")
        if "if (pid[i] <= 1 || !p14_sleeping" not in source:
            raise ValueError("source's child/sleep acceptance guard missing")
        print("PASS v1621 negative control: first five children accepted")
        print("PASS v1621 sixth child failed spawn/sleep check (!c)")
        print("PASS v1621 this fixture never reached its BRK pressure")
        print("OPEN v1621: why child 6 was refused or failed to sleep")
        return
    match = re.search(
        r"(?P<children>a{4})\[B(?P<before>[0-7]{6})/"
        r"(?P<resident_before>[0-7]{6})\]<"
        r"(?P<old>[0-7]{6})\+(?P<target>[0-7]{6})>"
        r"\[A(?P<after>[0-7]{6})/"
        r"(?P<resident_after>[0-7]{6})\]"
        r"\{(?P<before2>[0-7]{6})-(?P<after2>[0-7]{6})\}"
        r"!R(?P<children_exit>w{4})", trace)
    if not match:
        raise ValueError("missing full physical child/BRK/memory/refusal trace")
    values = {name: int(match.group(name), 8) for name in
              ("old", "target", "before", "after", "before2", "after2",
               "resident_before", "resident_after")}
    if values["old"] != 0o10000 or values["target"] != 0o16000:
        raise ValueError("the original 48K target was not used")
    if (values["before"] != values["before2"] or
            values["after"] != values["after2"]):
        raise ValueError("test memory accounting values changed")
    delta = values["target"] - values["old"]
    if values["after"] - values["before"] != delta:
        raise ValueError("this case does not show exact BRK-only growth")
    if values["resident_before"] != values["resident_after"]:
        raise ValueError("unexpected resident-overhead change")
    if "PURE" not in trace or "LOADED" not in trace:
        raise ValueError("physical 48K guest did not install PURE MRES")
    if "HALT instruction" not in trace:
        raise ValueError("physical guest did not terminate")
    print("PASS v1621 negative control: 48K PURE BRK 010000->016000 fits")
    print("PASS v1621 exact process-word growth 006000 octal,")
    print("  no net process residency reduction recorded")
    print("PASS v1621 original test refused to infer RAW packing (!R)")
    print("OPEN v1621: fitting workload with physical RAW pressure")


def main():
    if len(sys.argv) != 3:
        raise ValueError("usage: audit-fit-v1621.py GUEST.c CONSOLE.clean")
    audit(*sys.argv[1:])


if __name__ == "__main__":
    try:
        main()
    except (ValueError, OSError) as error:
        raise SystemExit("FAIL v1621 fitting control audit: " + str(error))
