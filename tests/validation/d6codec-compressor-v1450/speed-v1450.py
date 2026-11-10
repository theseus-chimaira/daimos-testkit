#!/usr/bin/env python3
"""Native PDP-6 encode/decode step counts for trusted bitmap v1450.

Generates independent encode-only and decode-only fixtures from the
exact v1426 DSH memory capture, then checks both counts separately.
The minimal CRT result check is included; output byte comparison is not.
"""
import argparse
import csv
import importlib.util
from pathlib import Path
import subprocess

ROOT = Path(__file__).resolve().parents[3]
STATES = ("idle_initial", "after_commands", "after_function")
MODES = ("encode", "decode")


def script(path, name):
    spec = importlib.util.spec_from_file_location(name, path)
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod


REFERENCE = script(
    ROOT / "tests/validation/d6codec-compressor-v1432/measure-v1432.py",
    "bitmap_reference_v1432")
STEP = script(
    ROOT / "tests/validation/d6codec-compare-v1422/measure-v1422.py",
    "step_count_v1422")


def adapt(path, mode):
    content = path.read_text().replace("v1432", "v1450").splitlines()
    if mode == "encode":
        for i, line in enumerate(content):
            if "pushj 17,bitmap_encode_v1450" in line:
                assert "caie 1," in content[i + 1]
                count = content[i + 1].split(",", 1)[1].strip()
                content[i + 1] = " caie 3,packed+" + count
                break
        else:
            raise ValueError("missing encoder call")
    else:
        for i, line in enumerate(content):
            if "pushj 17,bitmap_decode_v1450" in line:
                assert "caie 1," in content[i + 1]
                assert "jrst failed" in content[i + 2]
                del content[i + 1:i + 3]
                break
        else:
            raise ValueError("missing decoder call")
    path.write_text("\n".join(content) + "\n")


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--snapshot-dir", required=True, type=Path)
    parser.add_argument("--work", required=True, type=Path)
    parser.add_argument("--prefix", required=True, type=Path)
    args = parser.parse_args()
    args.work.mkdir(parents=True, exist_ok=True)
    rows = []
    for state in STATES:
        source = args.snapshot_dir / (state + "-physical-suffix-v1426.bin")
        import struct
        data = source.read_bytes()
        if len(data) % 8:
            raise ValueError("bad word boundary")
        words = list(struct.unpack("<%dQ" % (len(data) // 8), data))
        packed = REFERENCE.bitmap_encode(words)
        for mode in MODES:
            label = "%s_%s_v1450" % (state, mode)
            asm = args.work / (label + ".s")
            REFERENCE.fixture(asm, words, packed, mode)
            adapt(asm, mode)
            run = args.work / ("run-" + label)
            argv = [
                str(args.prefix / "bin/p10run"),
                "--machine", "pdp6", "--mode", "deposit",
                "--exec-mode", "step", "--step-limit", "1000000",
                "--start", "1000", "--timeout", "50",
                "--workdir", str(run), "--name", label,
                "--expect", "__test_exit=0",
                str(ROOT / "tests/validation/daimos-test-crt0-v1.s"),
                str(asm),
                str(ROOT / "tests/validation/d6codec-compressor-v1450/bitmap-v1450.s"),
            ]
            result = subprocess.run(
                argv, capture_output=True, text=True, timeout=85)
            if result.returncode:
                raise RuntimeError(result.stdout + result.stderr)
            count = STEP.count_steps(
                args.prefix / "bin/pdp6", run / (label + "-run.ini"),
                args.work / ("probe-" + label + ".ini"))
            rows.append({
                "state": state, "mode": mode,
                "raw_words": len(words), "packed_words": len(packed),
                "simh_instructions": count,
                "seconds_at_025_mips": round(count / 250000.0, 4),
            })
            print("NATIVE_BITMAP_V1449 %-18s %-6s %d instructions" %
                  (state, mode, count), flush=True)
    with (args.work / "speed-v1450.tsv").open("w") as f:
        writer = csv.DictWriter(f, fieldnames=list(rows[0]),
                                delimiter="\t", lineterminator="\n")
        writer.writeheader()
        writer.writerows(rows)
    print("PASS native PDP-6 bitmap encode/decode step measurement v1450")


if __name__ == "__main__":
    main()
