#!/usr/bin/env python3
"""Instruction-count native PDP-6 ENCODER comparison on real DSH RAM.

This benchmarks bounded in-memory encoder calls, not file I/O.
For all four variants the host independently verifies the encoded
stream word-for-word before this speed test. PDP-6 SIMH STEP
counts are not hardware cycles, and BLT has variable cost.
"""
import argparse
import csv
import importlib.util
from pathlib import Path
import re
import subprocess

STATES = ("idle_initial", "after_commands", "after_function")
CODECS = ("d6lz", "block", "grouped", "rle", "rle_measure",
          "rle_decode")


def load_count(path):
    spec = importlib.util.spec_from_file_location("counter_v1422", path)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def near_count(mod, sim, ini, scratch, max_steps, tolerance):
    original = ini.read_text()
    if not re.search(r"(?m)^step [0-9]+$", original):
        raise ValueError("invalid SIMH STEP script")
    high = 1000000
    while not mod.one_count(sim, original, high, scratch):
        high *= 2
        if high > max_steps:
            raise ValueError("encoder exceeded step budget %d" % max_steps)
    low = high // 2 if high > 1000000 else 0
    # Confirm that the retained lower bound is genuinely a failing
    # step budget (the first success could have occurred earlier).
    while low > 0 and mod.one_count(sim, original, low, scratch):
        high = low
        low //= 2
    while high - low > max(2, int(high * tolerance)):
        middle = (high + low) // 2
        if mod.one_count(sim, original, middle, scratch):
            high = middle
        else:
            low = middle
    return low + 1, high


def main():
    p = argparse.ArgumentParser()
    p.add_argument("--testkit", type=Path, required=True)
    p.add_argument("--work", type=Path, required=True)
    p.add_argument("--prefix", type=Path, required=True)
    p.add_argument("--tolerance", type=float, default=0.005)
    p.add_argument("--limit", type=int, default=64000000)
    p.add_argument("--states", nargs="*", default=STATES)
    p.add_argument("--codecs", nargs="*", default=CODECS)
    args = p.parse_args()
    mod = load_count(
        args.testkit / "tests/validation/d6codec-compare-v1422/"
        "measure-v1422.py")
    crt = (args.testkit /
           "tests/validation/daimos-test-crt0-v1.s")
    allrows = []
    for state in args.states:
        for codec in args.codecs:
            name = "%s-%s-bench-v1429" % (state, codec)
            fixture = args.work / "fixtures" / (name + ".s")
            engine = args.work / (
                "rle-v1376.s" if codec in ("rle", "rle_measure",
                                            "rle_decode")
                else "encoders-v1429.s")
            folder = args.work / "speed" / name
            folder.parent.mkdir(parents=True, exist_ok=True)
            argv = [
                str(args.prefix / "bin/p10run"),
                "--machine", "pdp6", "--mode", "deposit",
                "--exec-mode", "step", "--step-limit", "1000000",
                "--start", "1000", "--timeout", "60",
                "--workdir", str(folder), "--name", name,
                "--expect", "__test_exit=0",
                str(crt), str(fixture), str(engine),
            ]
            process = subprocess.run(
                argv, capture_output=True, text=True, timeout=85)
            ini = folder / (name + "-run.ini")
            if not ini.exists():
                raise RuntimeError(process.stdout + process.stderr)
            lowest, highest = near_count(
                mod, args.prefix / "bin/pdp6", ini,
                args.work / "speed" / ("probe-" + name + ".ini"),
                args.limit, args.tolerance)
            allrows.append({
                "state": state,
                "codec": codec,
                "simh_steps_min": lowest,
                "simh_steps_max": highest,
            })
            print("NATIVE_ENCODE %-16s %-7s steps=%d..%d" %
                  (state, codec, lowest, highest), flush=True)
    output = args.work / "encoder-steps-v1429.tsv"
    with output.open("w") as f:
        writer = csv.DictWriter(
            f, fieldnames=list(allrows[0]), delimiter="\t",
            lineterminator="\n")
        writer.writeheader()
        writer.writerows(allrows)
    print("PASS four native PDP-6 encoder timing comparisons")


if __name__ == "__main__":
    main()
