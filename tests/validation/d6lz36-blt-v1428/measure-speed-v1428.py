#!/usr/bin/env python3
"""Reproducible PDP-6 retired-instruction steps for D6LZ36 BLT v1428.

The baseline is the separately measured v1427 production core, on
identical SHA256-verified v1426 live shell memory. This is not a
cycle-accurate machine-time measurement.
"""
import argparse
import csv
import importlib.util
from pathlib import Path
import subprocess

ROOT = Path(__file__).resolve().parents[3]
STATES = ("idle_initial", "after_commands", "after_function")


def load(path, name):
    spec = importlib.util.spec_from_file_location(name, path)
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod


REF = load(
    ROOT / "tests/validation/d6lz36-dsh-live-v1427/compare-v1427.py",
    "compare_v1427")
STEPS = load(
    ROOT / "tests/validation/d6codec-compare-v1422/measure-v1422.py",
    "steps_v1422")


def match_statistics(packed, output_words):
    ip = 0
    op = 0
    remaining = 0
    control = 0
    count = 0
    copied = 0
    while op < output_words:
        if remaining == 0:
            control = packed[ip]
            ip += 1
            remaining = 36
        token = packed[ip]
        ip += 1
        if control & (1 << 35):
            length = ((token >> 7) & 127) + 3
            count += 1
            copied += length
            op += length
        else:
            op += 1
        control = (control << 1) & ((1 << 36) - 1)
        remaining -= 1
    if ip != len(packed) or op != output_words:
        raise ValueError("malformed match statistics")
    return count, copied


def main():
    p = argparse.ArgumentParser()
    p.add_argument("--daimos", type=Path, required=True)
    p.add_argument("--input", type=Path, required=True)
    p.add_argument("--library", type=Path, required=True)
    p.add_argument("--output", type=Path, required=True)
    p.add_argument("--prefix", type=Path, required=True)
    args = p.parse_args()
    args.output.mkdir(parents=True, exist_ok=True)
    codec = REF.ProductionCodec(args.library)
    old = {}
    with (ROOT / "tests/validation/d6lz36-dsh-live-v1427/"
          "speed-v1427.tsv").open() as f:
        for row in csv.DictReader(f, delimiter="\t"):
            if row["codec"] == "d6lz36":
                old[row["state"]] = row
    results = []
    for state in STATES:
        meta, words, digest = REF.PRIOR.read_live(args.input, state)
        prior = old[state]
        if len(words) != int(prior["decoded_words"]):
            raise ValueError("v1426 source size differs from baseline")
        packed = codec.encode(words)
        file = args.output / ("%s_bench_v1428.s" % state)
        REF.fixture(file, words, packed, verify=False)
        code = file.read_text()
        if code.count("blt 0,0127") != 1:
            raise ValueError("expected 40-word baseline installation")
        file.write_text(code.replace("blt 0,0127", "blt 0,0126"))
        name = "%s-d6lz36-blt-v1428" % state
        folder = args.output / ("run-" + name)
        cmd = [
            str(args.prefix / "bin/p10run"),
            "--machine", "pdp6", "--mode", "deposit",
            "--exec-mode", "step", "--step-limit", "1000000",
            "--start", "1000", "--timeout", "40",
            "--workdir", str(folder), "--name", name,
            "--expect", "__test_exit=0",
            str(ROOT / "tests/validation/daimos-test-crt0-v1.s"),
            str(file),
            str(args.daimos / "system/kernel/core/d6lz_pdp6.s"),
            str(args.daimos / "system/stand/pdp6/common/decompressor.inc"),
        ]
        completed = subprocess.run(
            cmd, capture_output=True, text=True, timeout=75)
        if completed.returncode:
            raise RuntimeError(completed.stdout + completed.stderr)
        steps = STEPS.count_steps(
            args.prefix / "bin/pdp6",
            folder / (name + "-run.ini"),
            args.output / ("%s-step-probe-v1428.ini" % state))
        count, copied = match_statistics(packed, len(words))
        # The fixture installs a 39-word low-core image once and
        # performs two six-word saved-AC BLTs in the runtime adapter.
        # Each LZ match adds one hardware BLT of MATCH_LENGTH words.
        blt_calls = count + 3
        blt_words = copied + 39 + 12
        # Illustration only: DEC 1964 F-61 BLT slow 2.4+1.2*N us;
        # arbitrarily charge other instructions 4 us each.
        oldsteps = int(prior["simh_steps"])
        old_slow_us = (oldsteps - 3) * 4.0 + 3 * 2.4 + 52 * 1.2
        slow_us = (
            (steps - blt_calls) * 4.0 +
            blt_calls * 2.4 + blt_words * 1.2)
        row = {
            "state": state,
            "decoded_words": len(words),
            "original_steps": oldsteps,
            "blt_steps": steps,
            "step_ratio": round(oldsteps / steps, 3),
            "match_blts": count,
            "match_words": copied,
            "illustrative_old_slow_us": round(old_slow_us, 1),
            "illustrative_blt_slow_us": round(slow_us, 1),
            "illustrative_time_ratio": round(old_slow_us / slow_us, 3),
            "source_sha256": digest,
        }
        results.append(row)
        print("NATIVE %-18s old=%7d blt=%5d instr_x=%.3f model_x=%.3f" %
              (state, oldsteps, steps, row["step_ratio"],
               row["illustrative_time_ratio"]), flush=True)
    with (args.output / "speed-v1428.tsv").open("w") as f:
        writer = csv.DictWriter(
            f, fieldnames=list(results[0]), delimiter="\t",
            lineterminator="\n")
        writer.writeheader()
        writer.writerows(results)
    print("PASS native PDP-6 BLT v1428 step comparison")


if __name__ == "__main__":
    main()
