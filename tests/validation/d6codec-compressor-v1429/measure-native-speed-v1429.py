#!/usr/bin/env python3
"""Native PDP-6 encoder-only step brackets for 3 real DSH snapshots.

Comparisons include KCC-generated grouped v1420 and block v1424
encoders, and actual v1376 in-memory RLE encoder. Output verification
is deliberately excluded from the step measurement (but run-v1429
validates both native encoders word-by-word separately).

SIMH step counts are NOT hardware microseconds. Brackets are within
one percent; the bounded search avoids an expensive exact search.
"""
import argparse
import csv
import importlib.util
from pathlib import Path
import subprocess

ROOT = Path(__file__).resolve().parents[3]
STATES = ("idle_initial", "after_commands", "after_function")
FORMATS = ("grouped", "block", "d6lz", "d6lz_fast",
           "rle", "rle_decode")


def imported(path, name):
    spec = importlib.util.spec_from_file_location(name, path)
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod


PREV = imported(
    ROOT / "tests/validation/d6codec-shell-live-v1426/measure-v1426.py",
    "live_v1426")
TOOL = imported(
    ROOT / "tests/validation/d6codec-compare-v1422/measure-v1422.py",
    "simh_steps_v1422")


def fixture(path, words, expected, fmt):
    if fmt == "rle":
        function = "kpack_ram_encode_v1376"
        capacity = expected
    elif fmt == "d6lz":
        function = "d6lz_encode_v1430"
        capacity = len(words) * 2 + 128
    elif fmt == "d6lz_fast":
        function = "d6lz_fast_encode_v1431"
        capacity = len(words) * 2 + 128
    else:
        function = fmt + "_encode_v1429"
        capacity = 2 * len(words) + 128
    text = [
        "/* Live DSH actual native encoder-only benchmark v1429 */",
        ".text",
        ".globl main",
        ".globl " + function,
        "main:",
        " movei 1,source",
        " movei 2,0%o" % len(words),
        " movei 3,compressed",
        " movei 4,0%o" % capacity,
        " pushj 17," + function,
        " caie 1,0%o" % expected,
        " jrst failed",
        " setz 1,",
        " popj 17,",
        "failed:",
        " movei 1,1",
        " popj 17,",
        ".data",
        "source:",
    ]
    text.extend(" .word 0%o" % w for w in words)
    text.extend([
        ".bss",
        "compressed: .block 0%o" % capacity,
        ".globl __test_exit",
        "__test_exit: .block 1",
    ])
    path.write_text("\n".join(text) + "\n")


def decode_fixture(path, packed, decoded_count):
    text = [
        "/* Real DSH native RAM RLE decoder-only benchmark v1429 */",
        ".text", ".globl main", ".globl kpack_ram_decode_v1376",
        "main:", " movei 1,source", " movei 2,0%o" % len(packed),
        " movei 3,decoded", " movei 4,0%o" % decoded_count,
        " pushj 17,kpack_ram_decode_v1376",
        " caie 1,0%o" % decoded_count, " jrst failed",
        " setz 1,", " popj 17,", "failed:",
        " movei 1,1", " popj 17,", ".data", "source:",
    ]
    text.extend(" .word 0%o" % w for w in packed)
    text.extend([
        ".bss", "decoded: .block 0%o" % decoded_count,
        ".globl __test_exit", "__test_exit: .block 1",
    ])
    path.write_text("\n".join(text) + "\n")


def bracket(sim, content, probe_path, high=50000000):
    # Do not attribute the validation comparison's memory reads to
    # the encoder. Stop within one percent of true instruction count.
    if not TOOL.one_count(sim, content, high, probe_path):
        raise ValueError("native encoder exceeded %d instructions" % high)
    low = 0
    while high - low > max(1, high // 100):
        middle = (low + high) // 2
        if TOOL.one_count(sim, content, middle, probe_path):
            high = middle
        else:
            low = middle
    return low, high


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--daimos", type=Path, required=True)
    parser.add_argument("--work", type=Path, required=True)
    parser.add_argument("--snapshots", type=Path, required=True)
    parser.add_argument("--prefix", type=Path, required=True)
    parser.add_argument("--codecs", default="grouped,block,rle")
    args = parser.parse_args()
    codecs = tuple(args.codecs.split(","))
    if not codecs or any(fmt not in FORMATS for fmt in codecs):
        raise ValueError("unsupported --codecs selection")
    args.work.mkdir(parents=True, exist_ok=True)
    lib = args.work / "libencoder-v1429.so"
    if not lib.exists():
        raise ValueError("first run v1429 native acceptance to compile encoders")
    encoder_mod = imported(
        ROOT / "tests/validation/d6codec-compressor-v1429/"
        "benchmark-v1429.py", "encoder_v1429")
    encoder = encoder_mod.Encoder(lib)
    native_rle = args.work / "kpack-ram-v1376-native.s"
    compile_rle = [
        str(args.prefix / "bin/kcc"), "-Pgnu99", "-O",
        "-x=pdp6", "-m=gas",
        "-I" + str(args.daimos / "system/kernel/core"),
        "-S", str(args.daimos /
                  "system/kernel/core/kpack_ram_rle_v1376.c"),
        "-o", str(native_rle),
    ]
    result = subprocess.run(compile_rle, capture_output=True, text=True)
    if result.returncode:
        raise RuntimeError(result.stdout + result.stderr)
    rle_library = args.work / "libkpack-ram-v1376.so"
    if not rle_library.exists():
        compile_host_rle = [
            "cc", "-std=c89", "-O2", "-Wall", "-Wextra", "-Werror",
            "-pedantic", "-fPIC", "-shared",
            "-I" + str(args.daimos / "system/kernel/core"),
            str(args.daimos / "system/kernel/core/kpack_ram_rle_v1376.c"),
            "-o", str(rle_library),
        ]
        result = subprocess.run(
            compile_host_rle, capture_output=True, text=True)
        if result.returncode:
            raise RuntimeError(result.stdout + result.stderr)
    rle_mod = PREV.ActualRamCodec(rle_library)
    rows = []
    for state in STATES:
        meta, source, _ = PREV.read_live(args.snapshots, state)
        for fmt in codecs:
            if fmt in ("rle", "rle_decode"):
                expected = len(rle_mod.roundtrip(source))
                engine = native_rle
            else:
                expected = len(encoder.encode(fmt, source))
                engine = args.work / (
                    "encode-d6lz-v1430.s" if fmt == "d6lz" else
                    "encode-d6lz-fast-v1431.s" if fmt == "d6lz_fast" else
                    "encode-%s-v1429.s" % fmt)
            name = "%s-%s-encode-steps-v1429" % (state, fmt)
            asm = args.work / (name + ".s")
            if fmt == "rle_decode":
                decode_fixture(asm, rle_mod.roundtrip(source), len(source))
            else:
                fixture(asm, source, expected, fmt)
            dest = args.work / ("run-" + name)
            cmd = [
                str(args.prefix / "bin/p10run"),
                "--machine", "pdp6", "--mode", "deposit",
                "--exec-mode", "step", "--step-limit", "50000000",
                "--start", "1000", "--timeout", "50",
                "--workdir", str(dest), "--name", name,
                "--expect", "__test_exit=0",
                str(ROOT / "tests/validation/daimos-test-crt0-v1.s"),
                str(asm), str(engine),
            ]
            result = subprocess.run(
                cmd, text=True, capture_output=True, timeout=95)
            if result.returncode:
                raise RuntimeError(result.stdout + result.stderr)
            ini = dest / (name + "-run.ini")
            low, high = bracket(
                args.prefix / "bin/pdp6", ini.read_text(),
                args.work / ("probe-" + name + ".ini"))
            rows.append({
                "state": state, "codec": fmt, "raw_words": len(source),
                "compressed_words": (expected if fmt != "rle_decode"
                                     else len(rle_mod.roundtrip(source))),
                "steps_lower": low, "steps_upper": high,
                "steps_per_input_upper": round(high / len(source), 2),
            })
            print("NATIVE_ENCODE %-17s %-8s steps=[%d,%d] words=%d" %
                  (state, fmt, low, high, len(source)), flush=True)
    with (args.work / "native-encoder-speed-v1429.tsv").open("w") as f:
        writer = csv.DictWriter(
            f, fieldnames=list(rows[0]), delimiter="\t",
            lineterminator="\n")
        writer.writeheader()
        writer.writerows(rows)
    print("PASS 9 native encoder step brackets (<1%)", flush=True)


if __name__ == "__main__":
    main()
