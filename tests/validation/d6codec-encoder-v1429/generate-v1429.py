#!/usr/bin/env python3
"""Fixtures for exact native PDP-6 in-memory compression comparisons.

References are the existing DAIMOS host D6LZ36, standalone RAM RLE
and earlier independent grouped/block implementations. All source
images are the actual DSH captures from v1426, or named controls.
"""
import argparse
import csv
import importlib.util
import random
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]


def load(path, name):
    spec = importlib.util.spec_from_file_location(name, path)
    obj = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(obj)
    return obj


PRIOR = load(
    ROOT / "tests/validation/d6codec-shell-live-v1426/measure-v1426.py",
    "prior_v1426")
D6LZ = load(
    ROOT / "tests/validation/d6lz36-dsh-live-v1427/compare-v1427.py",
    "d6lz_v1427")

ENCODERS = {
    "d6lz": "d6lz36_encode_v1429",
    "grouped": "d6grouped_encode_v1429",
    "block": "d6block_encode_v1429",
    "rle": "kpack_ram_encode_v1376",
}


def fixture(path, original, packed, codec, verify):
    fn = ENCODERS[codec]
    lines = [
        "/* v1429 PDP-6 encoder acceptance, no guest side effects. */",
        ".text", ".globl main", ".globl " + fn,
        "main:",
        " movei 1,source",
        " movei 2,0%o" % len(original),
        " movei 3,output",
        " movei 4,0%o" % len(packed),
        " pushj 17," + fn,
        " caie 1,0%o" % len(packed),
        " jrst failure",
    ]
    if verify:
        lines.extend([
            " setz 5,",
            "validate:",
            " move 6,output(5)",
            " came 6,expected(5)",
            " jrst failure",
            " aoj 5,",
            " caige 5,0%o" % len(packed),
            " jrst validate",
        ])
    lines.extend([
        " setz 1,",
        " popj 17,",
        "failure:",
        " movei 1,1",
        " popj 17,",
        ".data",
        "source:",
    ])
    lines.extend(" .word 0%o" % w for w in original)
    if verify:
        lines.append("expected:")
        lines.extend(" .word 0%o" % w for w in packed)
    lines.extend([
        ".bss",
        "output: .block 0%o" % len(packed),
        ".globl __test_exit",
        "__test_exit: .block 1",
    ])
    path.write_text("\n".join(lines) + "\n")


def measurement_fixture(path, source, output_words):
    """The extra exact-size pass required by current RAM RLE API."""
    lines = [
        "/* v1429 PDP-6 exact RAM RLE prepass timing. */",
        ".text", ".globl main", ".globl kpack_ram_measure_v1376",
        "main:",
        " movei 1,source",
        " movei 2,0%o" % len(source),
        " pushj 17,kpack_ram_measure_v1376",
        " caie 1,0%o" % output_words,
        " jrst failure",
        " setz 1,", " popj 17,",
        "failure:", " movei 1,1", " popj 17,",
        ".data", "source:",
    ]
    lines.extend(" .word 0%o" % word for word in source)
    lines.extend([
        ".bss", ".globl __test_exit",
        "__test_exit: .block 1",
    ])
    path.write_text("\n".join(lines) + "\n")


def rle_decode_fixture(path, source, packed, verify):
    """Exercise the real v1376 decoder alone, without measuring or encoding."""
    lines = [
        "/* v1429 native RAM RLE decompression cycle timing. */",
        ".text", ".globl main", ".globl kpack_ram_decode_v1376",
        "main:",
        " movei 1,compressed",
        " movei 2,0%o" % len(packed),
        " movei 3,restored",
        " movei 4,0%o" % len(source),
        " pushj 17,kpack_ram_decode_v1376",
        " caie 1,0%o" % len(source),
        " jrst failure",
    ]
    if verify:
        lines.extend([
            " setz 5,",
            "verify:",
            " move 6,restored(5)",
            " came 6,source(5)",
            " jrst failure",
            " aoj 5,",
            " caige 5,0%o" % len(source),
            " jrst verify",
        ])
    lines.extend([
        " setz 1,", " popj 17,",
        "failure:", " movei 1,1", " popj 17,",
        ".data", "compressed:",
    ])
    lines.extend(" .word 0%o" % word for word in packed)
    if verify:
        lines.append("source:")
        lines.extend(" .word 0%o" % word for word in source)
    lines.extend([
        ".bss", "restored: .block 0%o" % len(source),
        ".globl __test_exit", "__test_exit: .block 1",
    ])
    path.write_text("\n".join(lines) + "\n")


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--input", required=True, type=Path)
    parser.add_argument("--d6lz-library", required=True, type=Path)
    parser.add_argument("--rle-library", required=True, type=Path)
    parser.add_argument("--output", required=True, type=Path)
    args = parser.parse_args()
    args.output.mkdir(parents=True, exist_ok=True)
    ref_d6lz = D6LZ.ProductionCodec(args.d6lz_library)
    ref_rle = PRIOR.ActualRamCodec(args.rle_library)
    rng = random.Random(1429)
    samples = {}
    for state in ("idle_initial", "after_commands", "after_function"):
        meta, words, checksum = PRIOR.read_live(args.input, state)
        samples[state] = words
    samples["zeros_512"] = [0] * 512
    samples["random_256"] = [rng.getrandbits(36) for _ in range(256)]
    samples["repeat_512"] = [0o123456701234] * 512
    samples["mixed_1024"] = (
        [0] * 256 + [i for i in range(128)] * 4 +
        [0o1234] * 128 + [0] * 128)
    counts = []
    for state, words in samples.items():
        outputs = {
            "d6lz": ref_d6lz.encode(words),
            "rle": ref_rle.roundtrip(words),
            "block": PRIOR.BLOCK.encode(words),
            "grouped": PRIOR.GROUP.encode(words),
        }
        if state in ("idle_initial", "after_commands", "after_function"):
            measurement_fixture(
                args.output /
                ("%s-rle_measure-bench-v1429.s" % state),
                words, len(outputs["rle"]))
            for verify in (True, False):
                rle_decode_fixture(
                    args.output /
                    ("%s-rle_decode-%s-v1429.s" %
                     (state, "verify" if verify else "bench")),
                    words, outputs["rle"], verify)
        for codec, packed in outputs.items():
            if len(packed) == 0:
                raise ValueError("empty compressed stream")
            for verify in (True, False) if state in (
                    "idle_initial", "after_commands",
                    "after_function") else (True,):
                name = "%s-%s-%s-v1429" % (
                    state, codec, "verify" if verify else "bench")
                fixture(
                    args.output / (name + ".s"), words,
                    packed, codec, verify)
            counts.append({
                "state": state, "codec": codec,
                "raw_words": len(words), "compressed_words": len(packed),
            })
            print("FIXTURE %-17s %-7s raw=%5d compressed=%4d" %
                  (state, codec, len(words), len(packed)), flush=True)
    with (args.output / "sizes-v1429.tsv").open("w") as f:
        writer = csv.DictWriter(
            f, fieldnames=list(counts[0]),
            delimiter="\t", lineterminator="\n")
        writer.writeheader()
        writer.writerows(counts)
    print("PASS independent host reference fixtures for four native encoders")


if __name__ == "__main__":
    main()
