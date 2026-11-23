#!/usr/bin/env python3
"""Generate four independently executed unsafe native PURE terminal edits."""

from pathlib import Path
import sys


def create(original, directory):
    source = original.read_text(encoding="ascii")
    mutants = (
        ("unsafe-source-pin-v1900",
         "        and     7,[PPURE_META_PIN_MASK_V1609]\n"
         "        jumpn   7,ppure_detach_bad_v1609\n"
         "        hrrz    016,5",
         "        and     7,[PPURE_META_PIN_MASK_V1609]\n"
         "        ; v1900 unsafe: ignored pinned RAW source\n"
         "        hrrz    016,5"),
        ("unsafe-target-pin-v1900",
         "        and     7,[PPURE_META_PIN_MASK_V1609]\n"
         "        jumpn   7,ppure_detach_bad_v1609\n"
         "        hrrz    7,5",
         "        and     7,[PPURE_META_PIN_MASK_V1609]\n"
         "        ; v1900 unsafe: ignored pinned PROCESS target\n"
         "        hrrz    7,5"),
        ("unsafe-target-length-v1900",
         "        hlrz    4,1(011)               ; original complete APR length\n"
         "        came    7,4\n"
         "        jrst    ppure_detach_bad_v1609",
         "        hlrz    4,1(011)               ; original complete APR length\n"
         "        ; v1900 unsafe: accepted an arbitrary target size"),
        ("unsafe-uncertain-source-v1900",
         "        setz    015,\n"
         "ppure_detach_postfree_scan_v1900:",
         "        jrst    ppure_detach_publish_v1900\n"
         "ppure_detach_postfree_scan_v1900:"),
    )
    directory.mkdir(parents=True, exist_ok=True)
    for name, original_text, changed in mutants:
        if source.count(original_text) != 1:
            raise ValueError("original PURE terminal unsafe anchor drift: " + name)
        (directory / (name + ".s")).write_text(
            source.replace(original_text, changed, 1), encoding="ascii")
        print("v1900 prepared executed original ASM unsafe negative:", name)


if __name__ == "__main__":
    if len(sys.argv) != 3:
        raise SystemExit("usage: mutate-v1900.py original-pure-terminal.s output-dir")
    create(Path(sys.argv[1]), Path(sys.argv[2]))
