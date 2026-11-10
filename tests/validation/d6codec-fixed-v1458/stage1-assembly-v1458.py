#!/usr/bin/env python3
"""Assemble all five genuine Stage-1 sources with the relocated v1458 core.

Temporary source trees are created to preserve relative .include paths.
The baseline and candidate must each assemble successfully. Candidate
read-in length must shrink by at least eight 36-bit words; device-specific
layout and alignment may remove further padding words.
This is an assembly/layout test, not a cold-boot simulator test.
"""
import argparse
from pathlib import Path
import shutil
import subprocess

DEVICES = ("dsk", "drm", "dtc", "mtc", "ptr")


def main():
    p = argparse.ArgumentParser()
    p.add_argument("--daimos", required=True, type=Path)
    p.add_argument("--work", required=True, type=Path)
    p.add_argument("--prefix", required=True, type=Path)
    args = p.parse_args()
    src = args.daimos / "system/stand/pdp6"
    for version in ("v1452", "v1458"):
        work = args.work / version
        common = work / "common"
        common.mkdir(parents=True, exist_ok=True)
        for file in (src / "common").glob("*.inc"):
            shutil.copy2(file, common / file.name)
        sizes = {}
        for device in DEVICES:
            device_dir = work / device
            device_dir.mkdir(exist_ok=True)
            text = (src / device / "stage1.s").read_text()
            assert "block_decompressor_v1452.inc" in text
            if version == "v1458":
                text = text.replace("v1452", "v1458")
            asm = device_dir / "stage1.s"
            asm.write_text(text)
            obj = device_dir / (device + "-stage1-" + version + ".raw")
            result = subprocess.run([
                str(args.prefix / "bin/das"), "-F", "-K", "-O",
                str(obj), str(asm),
            ], capture_output=True, text=True, timeout=40)
            if result.returncode:
                raise RuntimeError(version + " " + device + ":\n" +
                                   result.stdout + result.stderr)
            nbytes = obj.stat().st_size
            if nbytes % 8:
                raise ValueError("unexpected byte size " + str(obj))
            sizes[device] = nbytes // 8
            print("STAGE1_ASSEMBLY_PASS", version, device,
                  sizes[device], "words", flush=True)
        (work / "word-counts.tsv").write_text(
            "device\treadin_words\n" +
            "".join("%s\t%d\n" % (d, sizes[d]) for d in DEVICES))
    for device in DEVICES:
        base = (args.work / "v1452" / device /
                (device + "-stage1-v1452.raw")).stat().st_size
        new = (args.work / "v1458" / device /
               (device + "-stage1-v1458.raw")).stat().st_size
        difference = (base - new) // 8
        if difference < 8:
            raise ValueError("unexpected Stage-1 size difference " +
                             device + ": " + str(difference))
        print("STAGE1_SAVING", device, difference, "words", flush=True)
    print("PASS five Stage-1 native assemblies, >=8 words saved each")


if __name__ == "__main__":
    main()
