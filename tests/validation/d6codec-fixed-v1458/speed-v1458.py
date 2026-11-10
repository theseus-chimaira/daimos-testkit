#!/usr/bin/env python3
"""Native PDP-6 fixed-low-core instruction counts, v1457 vs v1458.

Requires both native fixed-native test sets to have passed already.
SIMH counts BLT as one instruction regardless of the number of copied
words, so these measurements cannot be interpreted as exact CPU cycles.
"""
import argparse
import csv
import importlib.util
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]


def import_script(path, name):
    spec = importlib.util.spec_from_file_location(name, path)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


COUNT = import_script(
    ROOT / "tests/validation/d6codec-compare-v1422/measure-v1422.py",
    "block_step_count_v1422")


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--old-work", required=True, type=Path)
    parser.add_argument("--new-work", required=True, type=Path)
    parser.add_argument("--output", required=True, type=Path)
    parser.add_argument("--prefix", required=True, type=Path)
    args = parser.parse_args()
    args.output.mkdir(parents=True, exist_ok=True)
    results = []
    for scenario in ("one_literal", "overlap_one", "zeros", "real_dsh"):
        for version, directory in (("v1457", args.old_work),
                                   ("v1458", args.new_work)):
            label = scenario + "-" + version
            ini = directory / ("run-" + label) / (label + "-run.ini")
            contents = ini.read_text()
            old = "go 1000\n"
            assert contents.count(old) == 1
            contents = contents.replace(
                old, "deposit PC 1000\nexamine PC\nstep 1000000\n")
            run_ini = args.output / ("step-" + label + ".ini")
            run_ini.write_text(contents)
            count = COUNT.count_steps(
                args.prefix / "bin/pdp6", run_ini,
                args.output / ("probe-" + label + ".ini"))
            results.append({"sample": scenario, "decoder": version,
                            "steps": count})
            print("NATIVE_STEP", label, count, flush=True)
    with (args.output / "speed-v1458.tsv").open("w") as output:
        writer = csv.DictWriter(output, fieldnames=results[0].keys(),
                                delimiter="\t", lineterminator="\n")
        writer.writeheader()
        writer.writerows(results)
    print("PASS native PDP-6 low-core instruction comparison v1458")


if __name__ == "__main__":
    main()
