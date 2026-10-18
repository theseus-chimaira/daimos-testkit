#!/usr/bin/env python3
"""Validate AAP Type-551/Type-136 boot transfer evidence (v1).

The emulator's opt-in PDP6_AAP_DTC_WORD_AUDIT_V1 trace compares the words
actually delivered by Type-136 DATAI against the raw DTR image.  A full word
count and good controller status alone are not sufficient: after a direction
change, the controller can miss a block's DATA SYNC and silently read the
*following* block.  Reject such block substitutions even when all its data
words are individually correct.

This test consumes an AAP boot console capture and does not change the guest,
boot image, or source tape.  Filesystem/bootstrap RIM reads predating a valid
block-search alignment (block=-1) are excluded from the 128-word contract.
"""

import argparse
from pathlib import Path
import re
import sys

TRACE = "AAP_DTC_WORD_AUDIT_V1"
FIELD = re.compile(r"([a-z_]+)=(-?\d+)")
FIELDS = (
    "unit", "block", "observed", "reverse", "words", "mismatch", "invalid",
)


def validate(text: str, minimum: int) -> tuple[int, int, list[str]]:
    checked = [0, 0]
    errors = []
    for line_no, line in enumerate(text.splitlines(), 1):
        if TRACE not in line:
            continue
        data = {name: int(value) for name, value in FIELD.findall(line)}
        missing = [name for name in FIELDS if name not in data]
        if missing:
            errors.append(f"line {line_no}: missing fields: {', '.join(missing)}")
            continue
        if data["block"] < 0:
            continue
        rev = data["reverse"]
        if rev not in (0, 1):
            errors.append(f"line {line_no}: invalid reverse={rev}")
            continue
        checked[rev] += 1
        problems = []
        if data["block"] != data["observed"]:
            problems.append(
                f"requested/physical block {data['block']}/{data['observed']}"
            )
        if data["words"] != 128:
            problems.append(f"transferred {data['words']} instead of 128 words")
        if data["mismatch"] != 0 or data["invalid"] != 0:
            problems.append(
                f"wrong words={data['mismatch']} invalid={data['invalid']}"
            )
        if problems:
            errors.append(f"line {line_no}: {'; '.join(problems)}")
    if sum(checked) < minimum:
        errors.append(f"insufficient audited blocks: {sum(checked)} < {minimum}")
    if 0 in checked:
        errors.append(f"both directions required, got forward={checked[0]} reverse={checked[1]}")
    return checked[0], checked[1], errors


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("log", type=Path, help="AAP headless console capture")
    parser.add_argument("--minimum", type=int, default=10,
                        help="minimum valid physical block transfers (default 10)")
    args = parser.parse_args()
    forward, reverse, errors = validate(args.log.read_text(errors="replace"), args.minimum)
    for message in errors:
        print(f"AAP DTC AUDIT FAIL: {message}", file=sys.stderr)
    print(f"AAP DTC AUDIT: forward={forward} reverse={reverse} errors={len(errors)}")
    return 1 if errors else 0


if __name__ == "__main__":
    sys.exit(main())
