#!/usr/bin/env python3
"""Measure v1441 native decoder steps on identical compiled DXRs.

Tests full decoder entrypoint and direct-buffer adapter. Native STEP
counts include one BLT instruction regardless of copied word count,
so these figures are not elapsed PDP-6 hardware time.
"""
import argparse
import csv
import importlib.util
from pathlib import Path
import subprocess

ROOT = Path(__file__).resolve().parents[3]
VERSIONS = ("v1441",)


def load(path, name):
    spec = importlib.util.spec_from_file_location(name, path)
    result = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(result)
    return result


COUNT = load(
    ROOT / "tests/validation/d6codec-compare-v1422/measure-v1422.py",
    "count_steps_v1422")
FORMAT = load(
    ROOT / "tests/validation/d6codec-block-v1421/generate-v1421.py",
    "block_v1421")
GROUP = load(
    ROOT / "tests/validation/d6codec-fastpath-v1420/generate-v1420.py",
    "group_v1420")


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--daimos", type=Path, required=True)
    parser.add_argument("--boot", type=Path, required=True)
    parser.add_argument("--work", type=Path, required=True)
    parser.add_argument("--prefix", type=Path, required=True)
    args = parser.parse_args()
    args.work.mkdir(parents=True, exist_ok=True)
    samples = {
        "mixed_29": [
            x for path in sorted(args.boot.glob("*.dxr"))
            for x in GROUP.dxr.load(path)[:128]
        ],
        "dsh_first_2048": list(GROUP.dxr.load(
            args.boot / "userland-build/userland/dsh.dxr")[:2048]),
        "kcore_first_2048": list(GROUP.dxr.load(
            args.boot / "kcore.dxr")[:2048]),
    }
    results = []
    for name, raw in samples.items():
        encoded = FORMAT.encode(raw)
        if FORMAT.decode(encoded, len(raw)) != raw:
            raise ValueError("block host roundtrip rejected " + name)
        for version in VERSIONS:
            label = name + "-" + version
            fixture = args.work / (label + ".s")
            GROUP.emit(fixture, raw, encoded, False, (), version=version)
            work = args.work / ("run-" + label)
            cmd = [
                str(args.prefix / "bin/p10run"),
                "--machine", "pdp6", "--mode", "deposit",
                "--exec-mode", "step", "--step-limit", "1000000",
                "--start", "1000", "--timeout", "45",
                "--workdir", str(work), "--name", label,
                "--expect", "__test_exit=0",
                str(ROOT / "tests/validation/daimos-test-crt0-v1.s"),
                str(fixture),
                str(args.daimos / ("system/kernel/core/"
                    "d6codec_block_vfs_" + version + ".s")),
                str(args.daimos / ("system/kernel/core/"
                    "d6codec_block_core_" + version + ".s")),
            ]
            completed = subprocess.run(
                cmd, capture_output=True, text=True, timeout=70)
            if completed.returncode:
                raise RuntimeError(completed.stdout + completed.stderr)
            steps = COUNT.count_steps(
                args.prefix / "bin/pdp6",
                work / (label + "-run.ini"),
                args.work / ("probe-" + label + ".ini"))
            results.append({
                "sample": name, "version": version,
                "raw_words": len(raw), "compressed_words": len(encoded),
                "simh_instructions": steps,
            })
            print("SPEED %-18s %-5s %d steps" %
                  (name, version, steps), flush=True)
    with (args.work / "speed-v1441.tsv").open("w") as f:
        writer = csv.DictWriter(
            f, fieldnames=list(results[0]), delimiter="\t",
            lineterminator="\n")
        writer.writeheader()
        writer.writerows(results)
    print("PASS v1441 native PDP-6 decoder speed comparison")


if __name__ == "__main__":
    main()
