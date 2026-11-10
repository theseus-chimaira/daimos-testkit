#!/usr/bin/env python3
"""Test copied fixed low-core v1458 decoder in native PDP-6 simulation.

The actual Stage-1 relocates its decoder from a later part of a read-in
to address 000060 before expanding KINIT. This fixture performs the
same relocation, checks the native buffer stream, and checks exact
word-wise restored contents. No production media is changed.
"""
import argparse
import importlib.util
from pathlib import Path
import subprocess

ROOT = Path(__file__).resolve().parents[3]


def import_script(path, name):
    spec = importlib.util.spec_from_file_location(name, path)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


REFERENCE = import_script(
    ROOT / "tests/validation/d6codec-block-v1421/generate-v1421.py",
    "block_v1421")


def fixture(file, words, packed, accepted, needs_input=False):
    lines = [
        "/* Test real Stage-1 block low-core installation v1458. */",
        ".text", ".globl main",
        ".globl d6codec_block_fixed_v1458",
        "main:",
        " movei 1,d6b_image_start_v1458",
        " hrl 1,1",
        " hrri 1,060",
        " blt 1,060+(d6b_image_end_v1458-d6b_image_start_v1458)-1",
        " movei 3,compressed",
        " movei 4,0%o" % len(packed),
        " movei 12,restored",
        " movei 13,0%o" % len(words),
        " move 14,12",
        " setz 11,",
        " pushj 17,060",
    ]
    if accepted:
        lines.extend([
            " jumpn 0,fail", " jumpn 4,fail",
            " setz 5,", "check_words:",
            " move 6,source(5)", " came 6,restored(5)",
            " jrst fail", " aoj 5,",
            " caige 5,0%o" % len(words),
            " jrst check_words",
        ])
    else:
        expected = 1 if needs_input else -1
        lines.extend([
            " camn 0,[%d]" % expected, " jrst success",
            " jrst fail", "success:",
        ])
    lines.extend([
        " setz 1,", " popj 17,", "fail:",
        " movei 1,1", " popj 17,", ".data", "compressed:",
    ])
    lines.extend(" .word 0%o" % x for x in packed)
    lines.append("source:")
    lines.extend(" .word 0%o" % x for x in words)
    lines.extend([
        ".bss", "restored: .block 0%o" % len(words),
        ".globl __test_exit", "__test_exit: .block 1",
    ])
    file.write_text("\n".join(lines) + "\n")


def main():
    p = argparse.ArgumentParser()
    p.add_argument("--daimos", required=True, type=Path)
    p.add_argument("--boot", required=True, type=Path)
    p.add_argument("--work", required=True, type=Path)
    p.add_argument("--prefix", required=True, type=Path)
    args = p.parse_args()
    args.work.mkdir(parents=True, exist_ok=True)
    image = args.daimos / (
        "system/stand/pdp6/common/block_decompressor_v1458.inc")
    crt = ROOT / "tests/validation/daimos-test-crt0-v1.s"
    samples = {
        "one_literal": [0o123456701234],
        "overlap_one": [0o777000111222] * 415,
        "zeros": [0] * 4096,
        "distance_128": list(range(1, 129)) * 12,
        "mixed_dxrs": [
            word for path in sorted(args.boot.glob("*.dxr"))
            for word in REFERENCE.grouped.dxr.load(path)[:64]
        ],
        "real_dsh": list(REFERENCE.grouped.dxr.load(
            args.boot / "userland-build/userland/dsh.dxr")[:3072]),
    }
    tests = []
    for name, words in samples.items():
        encoded = REFERENCE.encode(words)
        assert REFERENCE.decode(encoded, len(words)) == words
        tests.append((name, words, encoded, True))
    tests += [
        ("bad_opcode", [0], [3 << 34], False),
        ("bad_reserved", [0], [(1 << 34) | 1], False),
        ("bad_backref", [0], [2 << 34], False),
        ("bad_output_length", [0], [(1 << 34) | (7 << 27)], False),
    ]
    # The *core* is resumable. A valid literal command whose input
    # ends before its payload returns NEED_INPUT (+1); the bounded
    # VFS frontend turns this into a malformed/truncated-stream error
    # when its declared compressed word count has been exhausted.
    tests.append(("bad_truncated", [5], [0], False))
    for name, raw, packed, accepted in tests:
        path = args.work / (name + "-v1458.s")
        fixture(path, raw, packed, accepted,
                needs_input=(name == "bad_truncated"))
        # Stage-1 includes the decoder in the very same assembly unit.
        # The copy length is a difference of two locally resolved labels.
        # DOBJ1 cannot relocate the difference between two *external*
        # symbols; a separate decoder object would be a different test
        # and (prior to DAS v1453) silently encoded BLT end 000057.
        path.write_text(path.read_text() + "\n" + image.read_text())
        label = name + "-v1458"
        command = [
            str(args.prefix / "bin/p10run"),
            "--machine", "pdp6", "--mode", "deposit",
            "--exec-mode", "go", "--start", "1000", "--timeout", "60",
            "--workdir", str(args.work / ("run-" + label)),
            "--name", label, "--expect", "__test_exit=0",
            str(crt), str(path),
        ]
        result = subprocess.run(
            command, capture_output=True, text=True, timeout=85)
        if result.returncode:
            raise RuntimeError(
                "FAILED " + name + "\n" +
                result.stdout + "\n" + result.stderr)
        print("LOW_CORE_PASS", name, "decoded", len(raw),
              "compressed", len(packed), flush=True)
    print("PASS v1458: six full exact native low-core decodes,",
          "five malformed stream rejections")


if __name__ == "__main__":
    main()
