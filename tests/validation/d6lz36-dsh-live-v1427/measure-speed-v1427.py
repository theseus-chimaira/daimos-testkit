#!/usr/bin/env python3
"""Actual PDP-6 decoder instruction steps on three real DSH RAM captures.

The SIMH STEP command counts BLT as a single instruction even when it
transfers many words. Accordingly, these measurements are not cycles.
"""
import argparse
import csv
import importlib.util
from pathlib import Path
import subprocess

STATES = ("idle_initial", "after_commands", "after_function")
FORMATS = ("d6lz36", "grouped", "block")


def import_script(path, name):
    spec = importlib.util.spec_from_file_location(name, path)
    loaded = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(loaded)
    return loaded


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--work", required=True, type=Path)
    parser.add_argument("--testkit", required=True, type=Path)
    parser.add_argument("--daimos", required=True, type=Path)
    parser.add_argument("--pdp10-prefix", required=True, type=Path)
    args = parser.parse_args()
    helper = import_script(
        args.testkit / "tests/validation/d6codec-compare-v1422/"
        "measure-v1422.py", "step_counter_v1422")
    transfer = import_script(
        args.testkit / "tests/validation/d6codec-compare-v1422/"
        "blt-stats-v1422.py", "blt_stats_v1422")
    results = []
    for state in STATES:
        for codec in FORMATS:
            case = "%s-%s-bench-v1427" % (state, codec)
            path = args.work / (case + ".s")
            folder = args.work / ("step-" + case)
            name = "step-" + case
            if codec == "d6lz36":
                sources = [
                    args.daimos / "system/kernel/core/d6lz_pdp6.s",
                    args.daimos /
                    "system/stand/pdp6/common/decompressor.inc",
                ]
            elif codec == "grouped":
                sources = [
                    args.daimos /
                    "system/kernel/core/d6codec_vfs_v1420.s",
                    args.daimos /
                    "system/kernel/core/d6codec_stream_v1420.s",
                ]
            else:
                sources = [
                    args.daimos /
                    "system/kernel/core/d6codec_block_vfs_v1424.s",
                    args.daimos /
                    "system/kernel/core/d6codec_block_core_v1424.s",
                ]
            argv = [
                str(args.pdp10_prefix / "bin/p10run"),
                "--machine", "pdp6", "--mode", "deposit",
                "--exec-mode", "step", "--step-limit", "1000000",
                "--start", "1000", "--timeout", "40",
                "--workdir", str(folder), "--name", name,
                "--expect", "__test_exit=0",
                str(args.testkit /
                    "tests/validation/daimos-test-crt0-v1.s"),
                str(path), *[str(p) for p in sources],
            ]
            completed = subprocess.run(
                argv, capture_output=True, text=True, timeout=70)
            if completed.returncode:
                raise RuntimeError(completed.stdout + completed.stderr)
            steps = helper.count_steps(
                args.pdp10_prefix / "bin/pdp6",
                folder / (name + "-run.ini"),
                args.work / ("probe-" + case + ".ini"))
            if codec == "d6lz36":
                # 40-word copy to low-core plus six AC saves and six
                # restores, each via BLT. Actual LZ matches use a
                # word-by-word loop, so there are no further BLTs.
                calls, copied = 3, 40 + 6 + 6
            else:
                packed = transfer.read_fixture(path)
                if codec == "grouped":
                    calls, copied, decoded = transfer.grouped_blt(packed)
                    calls += 2
                    copied += 14
                else:
                    calls, copied, decoded = transfer.block_blt(packed)
                    calls += 2
                    copied += 12
            rows = {r["state"]: int(r["raw_words"]) for r in
                    csv.DictReader(
                        (args.work / "results-v1427.tsv").open(),
                        delimiter="\t")
                    if r["region"] == "physical_sector_suffix"}
            decoded = rows[state]
            # DEC F-61 BLT slow: (2.4+1.2*n) microseconds. All other
            # instructions assigned nominal 4 us: an illustrative
            # historical machine cost model, not measured clocks.
            slow_us = ((steps - calls) * 4.0 +
                       calls * 2.4 + copied * 1.2)
            results.append({
                "state": state,
                "codec": codec,
                "decoded_words": decoded,
                "simh_steps": steps,
                "blt_calls": calls,
                "blt_words": copied,
                "illustrative_slow_us": round(slow_us, 1),
                "illustrative_words_per_s": round(
                    1000000.0 * decoded / slow_us),
            })
            print("SPEED %-17s %-8s steps=%7d BLT=%4d/%5d model_slow_us=%8.1f" %
                  (state, codec, steps, calls, copied, slow_us),
                  flush=True)
    with (args.work / "speed-v1427.tsv").open("w") as f:
        writer = csv.DictWriter(
            f, fieldnames=list(results[0]), delimiter="\t",
            lineterminator="\n")
        writer.writeheader()
        writer.writerows(results)
    print("PASS nine exact PDP-6 native decoder step measurements v1427")


if __name__ == "__main__":
    main()
