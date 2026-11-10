#!/usr/bin/env python3
"""Exact native PDP-6 instruction counts for both bitmap directions."""
import argparse
import csv
import importlib.util
from pathlib import Path
import subprocess

ROOT = Path(__file__).resolve().parents[3]
STATES = ("idle_initial", "after_commands", "after_function")
MODES = ("encode", "decode")


def load(path, name):
    spec = importlib.util.spec_from_file_location(name, path)
    result = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(result)
    return result


STEPS = load(
    ROOT / "tests/validation/d6codec-compare-v1422/measure-v1422.py",
    "step_counter_v1422")


def main():
    p = argparse.ArgumentParser()
    p.add_argument("--work", required=True, type=Path)
    p.add_argument("--prefix", required=True, type=Path)
    args = p.parse_args()
    results = []
    for state in STATES:
        for mode in MODES:
            name = "%s_%s_v1432" % (state, mode)
            work = args.work / ("steps-" + name)
            cmd = [
                str(args.prefix / "bin/p10run"),
                "--machine", "pdp6", "--mode", "deposit",
                "--exec-mode", "step", "--step-limit", "1000000",
                "--start", "1000", "--timeout", "40",
                "--workdir", str(work), "--name", name,
                "--expect", "__test_exit=0",
                str(ROOT / "tests/validation/daimos-test-crt0-v1.s"),
                str(args.work / "fixtures" / (name + ".s")),
                str(ROOT / "tests/validation/d6codec-compressor-v1432/"
                    "bitmap-v1432.s"),
            ]
            proc = subprocess.run(
                cmd, capture_output=True, text=True, timeout=75)
            if proc.returncode:
                raise RuntimeError(proc.stdout + proc.stderr)
            steps = STEPS.count_steps(
                args.prefix / "bin/pdp6",
                work / (name + "-run.ini"),
                args.work / ("step-probe-" + name + ".ini"))
            # The user-specified 0.25 MIPS is a nominal estimate,
            # NOT an instrumented hardware time measurement.
            results.append({
                "state": state, "direction": mode,
                "simh_instructions": steps,
                "time_at_250k_ips_seconds": round(steps / 250000.0, 4),
            })
            print("NATIVE_BITMAP %-17s %-6s %d instructions (%.4f s at 0.25 MIPS)" %
                  (state, mode, steps, steps / 250000.0), flush=True)
    with (args.work / "speed-v1432.tsv").open("w") as f:
        writer = csv.DictWriter(
            f, fieldnames=list(results[0]), delimiter="\t",
            lineterminator="\n")
        writer.writeheader()
        writer.writerows(results)
    print("PASS six native PDP-6 encoder/decoder step counts v1432")


if __name__ == "__main__":
    main()
