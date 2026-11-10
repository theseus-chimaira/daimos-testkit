#!/usr/bin/env python3
"""PDP-6 native decoder benchmarks on actual compiled executable words.

Both codecs decode identical output (different compressed inputs) using
their real direct-buffer frontend. The test harness excludes output
comparison from instruction counts; all input streams are independently
roundtripped by their host reference decoders before running native code.
"""
import argparse
import csv
import importlib.util
from pathlib import Path
import subprocess

ROOT = Path(__file__).resolve().parents[3]


def import_from(file, name):
    spec = importlib.util.spec_from_file_location(name, file)
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod


GEN = import_from(
    ROOT / "tests/validation/d6codec-fastpath-v1420/generate-v1420.py",
    "grouped_v1420")
BLOCK = import_from(
    ROOT / "tests/validation/d6codec-block-v1421/generate-v1421.py",
    "block_v1421")
D6LZ = import_from(
    ROOT / "tests/validation/d6codec-compressor-v1432/corpus-v1432.py",
    "d6lz_v1432")
STEP = import_from(
    ROOT / "tests/validation/d6codec-compare-v1422/measure-v1422.py",
    "steps_v1422")


def samples(boot):
    assembled = sorted(boot.glob("*.dxr"))
    merged = []
    for path in assembled:
        merged.extend(GEN.dxr.load(path)[:128])
    return {
        "mixed_29_prefixes": merged,
        "dsh_first_2048": list(
            GEN.dxr.load(
                boot / "userland-build/userland/dsh.dxr")[:2048]),
        "kcore_first_2048": list(
            GEN.dxr.load(boot / "kcore.dxr")[:2048]),
    }


def d6lz_fixture(path, raw, encoded):
    source = [
        "/* Native PDP-6 v1433 file decoder benchmark. */",
        ".text", ".globl main",
        ".globl d6lz36_decode_core",
        ".globl d6lz36_decode_buffer",
        ".globl vfs_read_words",
        "main:",
        " move 0,[d6lz36_decode_core,,060]",
        " blt 0,0126",  # v1428 optimized 39-word low-core decoder
        " movei 2,encoded", " movei 3,0%o" % len(encoded),
        " movei 4,decoded", " hrli 4,0%o" % len(raw),
        " pushj 17,d6lz36_decode_buffer",
        " jumpn 1,fail", " setz 1,", " popj 17,",
        "fail:", " movei 1,1", " popj 17,",
        "vfs_read_words:", " seto 1,", " popj 17,",
        ".data", "encoded:",
    ]
    source.extend(" .word 0%o" % w for w in encoded)
    source.extend([
        ".bss", "decoded: .block 0%o" % len(raw),
        ".globl __test_exit", "__test_exit: .block 1",
    ])
    path.write_text("\n".join(source) + "\n")


def run_one(args, name, fmt, path):
    label = "%s-%s-v1433" % (name, fmt)
    dest = args.output / ("run-" + label)
    cmd = [
        str(args.prefix / "bin/p10run"),
        "--machine", "pdp6", "--mode", "deposit",
        "--exec-mode", "step", "--step-limit", "1000000",
        "--start", "1000", "--timeout", "45",
        "--workdir", str(dest), "--name", label,
        "--expect", "__test_exit=0",
        str(ROOT / "tests/validation/daimos-test-crt0-v1.s"),
        str(path),
    ]
    if fmt == "d6lz":
        cmd.extend([
            str(args.daimos / "system/kernel/core/d6lz_pdp6.s"),
            str(args.daimos /
                "system/stand/pdp6/common/decompressor.inc"),
        ])
    else:
        cmd.extend([
            str(args.daimos /
                "system/kernel/core/d6codec_block_vfs_v1424.s"),
            str(args.daimos /
                "system/kernel/core/d6codec_block_core_v1424.s"),
        ])
    result = subprocess.run(
        cmd, capture_output=True, text=True, timeout=75)
    if result.returncode:
        raise RuntimeError(result.stdout + result.stderr)
    return STEP.count_steps(
        args.prefix / "bin/pdp6", dest / (label + "-run.ini"),
        args.output / ("probe-" + label + ".ini"))


def main():
    p = argparse.ArgumentParser()
    p.add_argument("--boot", type=Path, required=True)
    p.add_argument("--daimos", type=Path, required=True)
    p.add_argument("--d6lz-library", type=Path, required=True)
    p.add_argument("--prefix", type=Path, required=True)
    p.add_argument("--output", type=Path, required=True)
    args = p.parse_args()
    args.output.mkdir(parents=True, exist_ok=True)
    d6lz = D6LZ.ProductionCodec(args.d6lz_library)
    results = []
    for name, raw in samples(args.boot).items():
        encoded = {
            "d6lz": d6lz.encode(raw),
            "block": BLOCK.encode(raw),
        }
        if BLOCK.decode(encoded["block"], len(raw)) != raw:
            raise RuntimeError("block host roundtrip failed")
        for fmt in ("d6lz", "block"):
            test = args.output / ("%s-%s-bench-v1433.s" % (name, fmt))
            if fmt == "d6lz":
                d6lz_fixture(test, raw, encoded[fmt])
            else:
                GEN.emit(
                    test, raw, encoded[fmt], False, (), version="v1424")
            steps = run_one(args, name, fmt, test)
            row = dict(name=name, codec=fmt, raw_words=len(raw),
                       compressed_words=len(encoded[fmt]),
                       simh_decode_instructions=steps)
            results.append(row)
            print("NATIVE_FILE %-20s %-5s raw=%5d packed=%5d steps=%7d" %
                  (name, fmt, len(raw), len(encoded[fmt]), steps),
                  flush=True)
    with (args.output / "results-v1433.tsv").open("w") as f:
        writer = csv.DictWriter(
            f, fieldnames=list(results[0]), delimiter="\t",
            lineterminator="\n")
        writer.writeheader()
        writer.writerows(results)
    print("PASS six exact native file-decoder benchmark runs v1433")


if __name__ == "__main__":
    main()
