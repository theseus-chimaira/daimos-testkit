#!/usr/bin/env python3
"""Verify real restored user execution after v1620 MM/scheduler handoff.

The signal is the original child process's single user-code 'w' marker.
The test does not infer completed EXIT or WAIT from that single byte.
"""
import re
import subprocess
import sys
from pathlib import Path


def audit(trace_file, guest_source, manifest, image_path, dxrcheck):
    text = Path(trace_file).read_text()
    if ("PURE" not in text or "LOADED" not in text or
            "<010000+020000>" not in text):
        raise ValueError("trace is not the real 48K PURE pressure guest")
    marker = "Breakpoint, PC: 016770 "
    if text.count(marker) != 1:
        raise ValueError("missing unique physical restored-slot selection")
    start = text.index(marker)
    following = text.find("Step expired, PC:", start)
    if following < 0:
        raise ValueError("no executed CPU time after selecting slot 2")
    selected = text[start:following]
    if not re.search(r"(?m)^24233:\s*000000000002\s*$", selected):
        raise ValueError("physical current slot 2 not observed")
    if not re.search(r"(?m)^24307:\s*000001000002\s*$", selected):
        raise ValueError("selected owner is not unpinned PROCESS")
    if re.search(r"(?m)^w\s*$", text[:start]):
        raise ValueError("child marker already appeared before restoration")
    if len(re.findall(r"(?m)^w\s*$", selected)) != 1:
        raise ValueError("restored child did not execute its user marker")
    if len(re.findall(r"Step expired, PC:", text)) < 2:
        raise ValueError("real CPU did not complete two bounded steps")

    # This source is preserved with the EXACT guest image from v1615,
    # not an invented stand-in for the booted program.
    source = Path(guest_source)
    image = Path(image_path)
    if (source.name != "init-v1614.c" or image.name != "init.dxr"
            or source.parent != image.parent or
            not source.is_file() or not image.is_file()):
        raise ValueError("no matching preserved guest source and PURE DXR")
    code = source.read_text()
    expected = (
        "if (argc > 1) {", "dsys_read_words(0, &word, 1U)",
        "p14_data[0] != 012345670123UL",
        "p14_data[P14_IMAGE_WORDS - 1U] != 076543210765UL",
        "(void)p14_char('w');", "(void)dsys_exit(P14_STATUS);"
    )
    pos = -1
    for piece in expected:
        next_pos = code.find(piece, pos + 1)
        if next_pos < 0:
            raise ValueError("source-authentic child marker path drifted")
        pos = next_pos
    if code.count("p14_char('w')") != 1:
        raise ValueError("not exactly one user-code completion marker")
    if "#define P14_STATUS           057U" not in code:
        raise ValueError("guest child expected exit status changed")
    lines = Path(manifest).read_text().splitlines()
    if len([line for line in lines if line.startswith("F /SYSTEM/INIT ")]) != 1:
        raise ValueError("TSFS root lacks a unique executable image")
    entry = next(line for line in lines if line.startswith("F /SYSTEM/INIT "))
    if entry.split()[2] != str(image):
        raise ValueError("physical TSFS root does not use source's PURE DXR")
    output = subprocess.check_output(
        [dxrcheck, "-d", str(image)], text=True)
    if "purity=PURE" not in output.splitlines()[0]:
        raise ValueError("booted child did not have genuine PURE text")
    print("PASS v1621 physical unpinned slot-2 PROCESS selected")
    print("PASS v1621 user child resumed: read returned, data validated,")
    print("  original user C printed 'w' after scheduler selection")
    print("PASS v1621 guest source and TSFS manifest select a PURE DXR2")
    print("OPEN v1621: all four PIPE/WAIT/EXIT and positive net RAM")


def main():
    if len(sys.argv) != 6:
        raise ValueError(
            "usage: audit-user-v1621.py TRACE.clean ORIGINAL.c "
            "TSFS.manifest INIT.dxr DXRCHECK")
    audit(*sys.argv[1:])


if __name__ == "__main__":
    try:
        main()
    except (ValueError, OSError, subprocess.CalledProcessError) as error:
        raise SystemExit("FAIL v1621 user resume audit: " + str(error))
