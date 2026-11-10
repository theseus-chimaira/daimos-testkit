#!/usr/bin/env python3
"""Generate a real PDP-6 ABI test: bitmap preserves AC10..AC15."""
import argparse
from pathlib import Path


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    raw = [0 if i % 5 else ((i + 1) << 22) | (i << 6) | 1
           for i in range(73)]
    packed_words = (len(raw) + 35) // 36 + sum(value != 0 for value in raw)
    lines = [
        "/* v1451 PDP-6 ABI: encode/decode preserve all AC10..AC15. */",
        ".text", ".globl main",
        ".globl bitmap_encode_v1451", ".globl bitmap_decode_v1451",
        "main:",
    ]
    registers = list(range(10, 16))
    for reg in registers:
        lines.append(" move %d,[0%o]" % (reg, (reg + 4) * 0o12345671))
    lines.extend([
        " movei 1,source", " movei 2,0%o" % len(raw),
        " movei 3,packed", " pushj 17,bitmap_encode_v1451",
        " caie 3,packed+0%o" % packed_words, " jrst bad",
    ])
    for reg in registers:
        lines.extend([
            " came %d,[0%o]" % (reg, (reg + 4) * 0o12345671),
            " jrst bad",
        ])
    lines.extend([
        " movei 1,packed", " movei 3,restored",
        " movei 4,0%o" % len(raw),
        " pushj 17,bitmap_decode_v1451",
    ])
    for reg in registers:
        lines.extend([
            " came %d,[0%o]" % (reg, (reg + 4) * 0o12345671),
            " jrst bad",
        ])
    lines.extend([
        " setz 5,", "check:",
        " move 6,source(5)", " came 6,restored(5)",
        " jrst bad", " aoj 5,",
        " caige 5,0%o" % len(raw), " jrst check",
        " setz 1,", " popj 17,", "bad:",
        " movei 1,1", " popj 17,", ".data", "source:",
    ])
    lines.extend(" .word 0%o" % v for v in raw)
    lines.extend([
        ".bss", "packed: .block 0%o" % packed_words,
        "restored: .block 0%o" % len(raw),
        ".globl __test_exit", "__test_exit: .block 1",
    ])
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text("\n".join(lines) + "\n")


if __name__ == "__main__":
    main()
