#!/usr/bin/env python3
"""Native PDP-6 D6LZ36 BLT regressions from the unchanged host encoder.

The actual shared production decoder is supplied by the test runner.
The fixed installation length is 39 words, as proved by DAS; all
compressed payloads have the original D6LZ36 bitstream format.
"""
import argparse
import importlib.util
import random
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]
SOURCE = (ROOT / "tests/validation/d6lz36-dsh-live-v1427/compare-v1427.py")
spec = importlib.util.spec_from_file_location("d6lz36_v1427", SOURCE)
reference = importlib.util.module_from_spec(spec)
spec.loader.exec_module(reference)


def compiled_fixture(source, packed, provider_words, output):
    code = [
        "/* PDP-6 v1428 native D6LZ36 BLT fixture. */",
        ".text", ".globl main", ".globl d6lz36_decode_core",
        ".globl d6lz36_decode_vfs", ".globl d6lz36_decode_buffer",
        ".globl vfs_read_words", "main:",
        " move 0,[d6lz36_decode_core,,060]",
        " blt 0,0126",  # 39 text words; 060 through 0126 inclusive
    ]
    if provider_words:
        code.extend([
            " movei 1,0%o" % provider_words,
            " setz 2,", " movei 3,0%o" % len(packed),
            " movei 4,decoded", " hrli 4,0%o" % len(source),
            " pushj 17,d6lz36_decode_vfs",
        ])
    else:
        code.extend([
            " movei 2,compressed", " movei 3,0%o" % len(packed),
            " movei 4,decoded", " hrli 4,0%o" % len(source),
            " pushj 17,d6lz36_decode_buffer",
        ])
    code.extend([
        " jumpn 1,fail", " movei 5,0",
        "cmp:", " move 6,source(5)", " came 6,decoded(5)",
        " jrst fail", " aoj 5,",
        " caige 5,0%o" % len(source), " jrst cmp",
        " setz 1,", " popj 17,",
        "fail:", " movei 1,1", " popj 17,",
        "vfs_read_words:",
    ])
    if provider_words:
        code.extend([
            # AC1=maximum allowed short read in this test provider.
            # AC2=word offset, AC3=destination, AC4=requested count.
            " move 5,4", " camle 5,1", " move 5,1",
            " move 6,[0%o]" % len(packed), " sub 6,2",
            " jumple 6,provider_fail", " camle 5,6", " move 5,6",
            " move 1,5", " movei 6,compressed", " add 6,2",
            " move 7,3",
            "copy_provider:", " move 0,0(6)", " movem 0,0(7)",
            " aoj 6,", " aoj 7,", " sojg 5,copy_provider",
            " popj 17,", "provider_fail:", " seto 1,", " popj 17,",
        ])
    else:
        code.extend([" seto 1,", " popj 17,"])
    code.extend([".data", "source:"])
    code.extend(" .word 0%o" % w for w in source)
    code.append("compressed:")
    code.extend(" .word 0%o" % w for w in packed)
    code.extend([
        ".bss", "decoded: .block 0%o" % len(source),
        ".globl __test_exit", "__test_exit: .block 1",
    ])
    output.write_text("\n".join(code) + "\n")


def malformed_fixture(encoded, expected_count, path):
    """Exercise established pre-BLT checks on an invalid match."""
    lines = [
        "/* v1428 malformed descriptor must be rejected before BLT. */",
        ".text", ".globl main",
        ".globl d6lz36_decode_core",
        ".globl d6lz36_decode_buffer",
        ".globl vfs_read_words",
        "main:",
        " move 0,[d6lz36_decode_core,,060]",
        " blt 0,0126",
        " movei 2,compressed",
        " movei 3,0%o" % len(encoded),
        " movei 4,decoded",
        " hrli 4,0%o" % expected_count,
        " pushj 17,d6lz36_decode_buffer",
        " camn 1,[-1]",
        " jrst ok",
        " movei 1,1", " popj 17,",
        "ok:", " setz 1,", " popj 17,",
        "vfs_read_words:", " seto 1,", " popj 17,",
        ".data", "compressed:",
    ]
    lines.extend(" .word 0%o" % w for w in encoded)
    lines.extend([
        ".bss", "decoded: .block 0%o" % expected_count,
        ".globl __test_exit", "__test_exit: .block 1",
    ])
    path.write_text("\n".join(lines) + "\n")


def main():
    p = argparse.ArgumentParser()
    p.add_argument("--library", type=Path, required=True)
    p.add_argument("--output", type=Path, required=True)
    p.add_argument("--snapshot", type=Path, required=True)
    a = p.parse_args()
    a.output.mkdir(parents=True, exist_ok=True)
    codec = reference.ProductionCodec(a.library)
    rng = random.Random(1428)
    cases = {
        "one_word": [0o123456701234],
        "two_words": [0o777111, 0o111777],
        "zeros_max": [0] * 8450,
        "overlap_one": [0o123456123456] * 4197,
        "distance_128": list(range(1, 129)) * 28,
        "literal": [rng.getrandbits(36) for _ in range(400)],
        "mixed": ([0] * 275 + list(range(64)) * 13 +
                  [0o773355] * 800 + [0] * 286),
    }
    for name in ("idle_initial", "after_commands", "after_function"):
        info, data, digest = reference.PRIOR.read_live(a.snapshot, name)
        cases["live_" + name] = data
    for name, source in cases.items():
        packed = codec.encode(source)
        for provider in (0, 1, 7, 64) if name in (
                "distance_128", "mixed", "live_idle_initial") else (0,):
            suffix = "direct" if provider == 0 else "refill_%d" % provider
            target = a.output / (name + "_" + suffix + "_v1428.s")
            compiled_fixture(source, packed, provider, target)
        print("VECTOR", name, "input", len(source), "D6LZ36", len(packed))

    # Illegal first match, reserved descriptor fields, backward
    # distance with no preceding word, and output-length overflow.
    malformed = {
        "first_match": ([1 << 35, 0], 3),
        "reserved_bits": ([1 << 35, 1 << 20], 3),
        "length_overflow": ([1 << 34, 0o17, 0], 2),
        "truncated": ([0], 1),
    }
    for name, (stream, length) in malformed.items():
        malformed_fixture(
            stream, length, a.output / ("bad_" + name + "_v1428.s"))
    print("PASS v1428 host-verified direct/refill/bad-stream fixtures")


if __name__ == "__main__":
    main()
