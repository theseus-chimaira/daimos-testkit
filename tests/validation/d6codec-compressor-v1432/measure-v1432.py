#!/usr/bin/env python3
"""Exact packed-word sizes and native test fixtures for bitmap v1432."""
import argparse
import csv
import hashlib
import importlib.util
import json
from pathlib import Path
import struct

ROOT = Path(__file__).resolve().parents[3]
STATES = ("idle_initial", "after_commands", "after_function")


def bitmap_encode(words):
    result = []
    for start in range(0, len(words), 36):
        group = words[start:start + 36]
        flags = 0
        values = []
        for idx, value in enumerate(group):
            if value:
                flags |= 1 << (35 - idx)
                values.append(value)
        result.append(flags)
        result.extend(values)
    return result


def fixture(path, raw, packed, mode):
    """Emit a standalone PDP-6 native fixture, no native test instrumentation."""
    lines = [
        "/* Actual PDP-6 bitmap v1432 native acceptance and timing. */",
        ".text", ".globl main",
        ".globl bitmap_encode_v1432", ".globl bitmap_decode_v1432",
        "main:",
    ]
    if mode in ("both", "encode"):
        lines.extend([
            " movei 1,raw", " movei 2,0%o" % len(raw),
            " movei 3,packed", " movei 4,0%o" % len(packed),
            " pushj 17,bitmap_encode_v1432",
            " caie 1,0%o" % len(packed), " jrst failed",
        ])
    if mode == "both":
        lines.extend([
            " setz 5,", "compare_packed:",
            " move 6,reference(5)", " came 6,packed(5)",
            " jrst failed", " aoj 5,",
            " caige 5,0%o" % len(packed), " jrst compare_packed",
        ])
    if mode in ("both", "decode"):
        lines.extend([
            " movei 1," + ("packed" if mode == "both" else "reference"),
            " movei 2,0%o" % len(packed),
            " movei 3,restored", " movei 4,0%o" % len(raw),
            " pushj 17,bitmap_decode_v1432",
            " caie 1,0%o" % len(raw), " jrst failed",
        ])
    if mode == "both":
        lines.extend([
            " setz 5,", "compare_raw:",
            " move 6,raw(5)", " came 6,restored(5)",
            " jrst failed", " aoj 5,",
            " caige 5,0%o" % len(raw), " jrst compare_raw",
        ])
    lines.extend([
        " setz 1,", " popj 17,",
        "failed:", " movei 1,1", " popj 17,",
        ".data", "raw:",
    ])
    lines.extend(" .word 0%o" % x for x in raw)
    lines.append("reference:")
    lines.extend(" .word 0%o" % x for x in packed)
    lines.extend([
        ".bss", "packed: .block 0%o" % len(packed),
        "restored: .block 0%o" % len(raw),
        ".globl __test_exit", "__test_exit: .block 1",
    ])
    path.write_text("\n".join(lines) + "\n")


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--input", required=True, type=Path)
    parser.add_argument("--output", required=True, type=Path)
    args = parser.parse_args()
    args.output.mkdir(parents=True, exist_ok=True)
    earlier = {}
    with (ROOT / "tests/validation/d6codec-shell-live-v1426/"
          "results-live-v1426.tsv").open() as f:
        for row in csv.DictReader(f, delimiter="\t"):
            earlier[(row["state"], row["region"])] = row
    rows = []
    for state in STATES:
        path = args.input / ("%s-physical-suffix-v1426.bin" % state)
        content = path.read_bytes()
        words = list(struct.unpack("<%dQ" % (len(content) // 8), content))
        expected = earlier[(state, "physical_sector_suffix")]
        sha = hashlib.sha256(content).hexdigest()
        if sha != expected["sha256_source"] or len(words) != int(
                expected["raw_words"]):
            raise ValueError("actual DSH snapshot mismatch")
        packed = bitmap_encode(words)
        for mode in ("both", "encode", "decode"):
            fixture(args.output / (
                "%s_%s_v1432.s" % (state, mode)), words, packed, mode)
        row = dict(state=state, raw_words=len(words),
                   nonzero_words=sum(w != 0 for w in words),
                   bitmap_words=len(packed),
                   source_sha256=sha)
        rows.append(row)
        print("BITMAP %-17s %d raw -> %d compressed" %
              (state, len(words), len(packed)), flush=True)
    for name, sample in {
        "zeros": [0] * 720,
        "literal": list(range(1, 400)),
        "one": [0o1234567],
        "last_bit": [0] * 35 + [0o3456734567],
        "mixed": ([0, 7, 0, 9] * 125),
    }.items():
        fixture(args.output / (name + "_both_v1432.s"),
                sample, bitmap_encode(sample), "both")
    with (args.output / "results-v1432.tsv").open("w") as f:
        writer = csv.DictWriter(f, fieldnames=list(rows[0]),
                                delimiter="\t", lineterminator="\n")
        writer.writeheader()
        writer.writerows(rows)


if __name__ == "__main__":
    main()
