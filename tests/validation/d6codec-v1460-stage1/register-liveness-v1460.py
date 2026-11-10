#!/usr/bin/env python3
"""Confirm the v1460 tape-boot entry preservation costs zero PDP-6 words.

The v1458 block core clobbers AC5 for back-reference addresses but does
not use AC16. Both tape loaders used AC5 to hold KINIT's entry address
across decoding and subsequently jumped through the corrupted value.

Assemble both loader versions with identical included decoder source,
then compare each 36-bit read-in word. The fixed image must have the
same size, and no instruction other than the entry-address references
may change. Actual cold-boot acceptance is a separate integration test.
"""
import argparse
from pathlib import Path
import re
import shutil
import struct
import subprocess


BASELINE = "ad4d9c18"
DEVICES = {"dtc": 5, "mtc": 4}


def read_words(path):
    data = path.read_bytes()
    if len(data) % 8:
        raise ValueError("unaligned native PDP-6 image: " + str(path))
    return struct.unpack("<%dQ" % (len(data) // 8), data)


def assemble(das, source, output):
    proc = subprocess.run(
        [str(das), "-F", "-K", "-O", str(output), str(source)],
        capture_output=True, text=True, timeout=40)
    if proc.returncode:
        raise ValueError("DAS failed: " + proc.stdout + proc.stderr)
    return read_words(output)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--daimos", required=True, type=Path)
    ap.add_argument("--prefix", required=True, type=Path)
    ap.add_argument("--work", required=True, type=Path)
    args = ap.parse_args()
    args.work.mkdir(parents=True, exist_ok=True)
    core = (args.daimos / "system/stand/pdp6/common/"
            "block_decompressor_v1458.inc").read_text()
    if re.search(r"(?m)^\s+[a-z][a-z0-9]*\s+0?16\s*[,\s]", core):
        raise ValueError("fixed decoder modifies AC16")

    for device, expected_diffs in DEVICES.items():
        rel = "system/stand/pdp6/%s/stage1.s" % device
        original = subprocess.run(
            ["git", "-C", str(args.daimos), "show", BASELINE + ":" + rel],
            capture_output=True, text=True, check=True).stdout
        current = (args.daimos / rel).read_text()
        if current.count("jrst 0(016)") != expected_diffs - 3:
            raise ValueError("wrong entry-register handoff: " + device)
        if "jrst 0(05)" in current:
            raise ValueError("stale clobbered entry register: " + device)

        images = []
        for version, source in (("v1459", original), ("v1460", current)):
            directory = args.work / version
            (directory / "common").mkdir(parents=True, exist_ok=True)
            target = directory / device
            target.mkdir(exist_ok=True)
            for inc in (args.daimos / "system/stand/pdp6/common").glob("*.inc"):
                shutil.copy2(inc, directory / "common" / inc.name)
            src = target / "stage1.s"
            src.write_text(source)
            images.append(assemble(args.prefix / "bin/das", src,
                                   target / ("stage1-" + version + ".raw")))

        old, new = images
        if len(old) != len(new):
            raise ValueError("Stage-1 size changed for " + device)
        changes = [i for i, (a, b) in enumerate(zip(old, new)) if a != b]
        if len(changes) != expected_diffs:
            raise ValueError("unexpected code changes: %s: %s" %
                             (device, changes))
        print("V1460_STAGE1_REGISTER_PASS", device, "words", len(new),
              "changed_instructions", len(changes),
              "new_words", len(new) - len(old), flush=True)
    print("PASS v1460 DTC/MTC entry-register liveness and zero growth")


if __name__ == "__main__":
    main()
