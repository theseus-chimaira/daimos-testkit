#!/usr/bin/env python3
"""Negative PDP-6 tests for grouped v1420 and experimental block v1421."""
import argparse
from pathlib import Path

MASK = (1 << 36) - 1


def write_fixture(file, codec, packed, output_len, alias=False):
    version = "v1420" if codec == "grouped" else "v1421"
    code = [
        "/* Expected rejection of a malformed codec stream v1422. */",
        ".text",
        ".globl main",
        ".globl d6codec_decode_buffer_" + version,
        "main:",
        " movei 2,compressed",
        " movei 3,0%o" % len(packed),
        " movei 4,%s" % ("compressed" if alias else "decoded"),
        " hrli 4,0%o" % output_len,
        " pushj 17,d6codec_decode_buffer_" + version,
        " camn 1,[-1]",
        " jrst pass",
        " movei 1,1",
        " popj 17,",
        "pass:",
        " setz 1,",
        " popj 17,",
        ".globl vfs_read_words",
        "vfs_read_words:",
        " seto 1,",
        " popj 17,",
        ".data",
        "compressed:"
    ]
    code.extend(" .word 0%o" % (word & MASK) for word in packed)
    code.extend([
        ".bss",
        "decoded: .block 0%o" % output_len,
        ".globl __test_exit",
        "__test_exit: .block 1"
    ])
    file.write_text("\n".join(code) + "\n")


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("output_dir", type=Path)
    args = parser.parse_args()
    args.output_dir.mkdir(parents=True, exist_ok=True)
    # Grouped: count 1, high flag bit set, packed left descriptor.
    control_literal = 1 << 30
    control_match = (1 << 30) | (1 << 29)
    descriptor = lambda kind, n, dist: (
        ((kind << 16) | (n << 9) | dist) << 18)
    grouped = {
        "zero_control": ([0], 4, False),
        "oversize_group": ([31 << 30], 4, False),
        "noncanonical_flags": ([control_match | (1 << 28),
                                descriptor(1, 4, 0)], 4, False),
        "zero_match_length": ([control_match, descriptor(0, 0, 1)],
                              4, False),
        "odd_padding": ([control_match, descriptor(1, 4, 0) | 1],
                        4, False),
        "zero_distance": ([control_match, descriptor(1, 4, 1)],
                          4, False),
        "before_origin": ([control_match, descriptor(0, 4, 1)],
                          4, False),
        "overflow": ([control_match, descriptor(1, 8, 0)],
                     4, False),
        "truncated_literal": ([control_literal], 1, False),
        "trailing_words": ([control_literal, 0o123, 0o456],
                           1, False),
        "bad_kind": ([control_match, descriptor(3, 4, 0)],
                     4, False),
        "overlap_buffer": ([control_literal, 0o123],
                           1, True)
    }
    # Block v1421 commands have two type bits, seven length bits, nine
    # distance bits and exactly 18 reserved zero bits.
    block_cmd = lambda kind, n, dist=0: (
        (kind << 34) | ((n - 1) << 27) |
        ((dist - 1 if kind == 2 else dist) << 18))
    block = {
        "zero_source": ([], 1, False),
        "bad_opcode": ([block_cmd(3, 1)], 1, False),
        "reserved_bits": ([block_cmd(1, 1) | 1], 1, False),
        "literal_distance": ([block_cmd(0, 1, 1), 0o123],
                             1, False),
        "zero_distance": ([block_cmd(1, 1, 1)], 1, False),
        "before_origin": ([block_cmd(2, 1, 1)], 1, False),
        "overflow": ([block_cmd(1, 8)], 4, False),
        "truncated_literal": ([block_cmd(0, 2), 0o123],
                              2, False),
        "trailing_words": ([block_cmd(0, 1), 0o123, 0o456],
                           1, False),
        "overlap_buffer": ([block_cmd(0, 1), 0o123],
                           1, True)
    }
    for codec, cases in (("grouped", grouped), ("block", block)):
        for name, (packed, output_len, alias) in cases.items():
            path = args.output_dir / (
                "%s_%s_v1422.s" % (codec, name))
            write_fixture(path, codec, packed, output_len, alias)
    print("ERROR_FIXTURES grouped=%d block=%d" %
          (len(grouped), len(block)))


if __name__ == "__main__":
    main()
