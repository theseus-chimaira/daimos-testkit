#!/usr/bin/env python3
"""Exact SIMH instruction-step brackets for the register-resident engine."""
import importlib.util
from pathlib import Path
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[3]
spec = importlib.util.spec_from_file_location(
    "measure_v1422",
    ROOT / "tests/validation/d6codec-compare-v1422/measure-v1422.py")
measurement = importlib.util.module_from_spec(spec)
spec.loader.exec_module(measurement)


def main():
    work, daimos = (Path(arg).resolve() for arg in sys.argv[1:])
    engine = daimos / "system/kernel/core/d6codec_block_core_v1424.s"
    adapter = daimos / "system/kernel/core/d6codec_block_vfs_v1424.s"
    runner = Path.home() / "cross/bin/p10run"
    sim = Path.home() / "cross/bin/pdp6"
    crt = ROOT / "tests/validation/daimos-test-crt0-v1.s"
    results = []
    for task in ("zeros", "normal", "literal", "overlap", "worst"):
        source = work / ("%s_bench_v1421.s" % task)
        fixture = work / ("%s_bench_v1424.s" % task)
        fixture.write_text(source.read_text().replace("v1421", "v1424"))
        folder = work / ("step-%s" % task)
        name = "register-%s-v1424" % task
        argv = [
            str(runner), "--machine", "pdp6", "--mode", "deposit",
            "--exec-mode", "step", "--step-limit", "1000000",
            "--start", "1000", "--timeout", "40",
            "--workdir", str(folder), "--name", name,
            "--expect", "__test_exit=0", str(crt), str(fixture),
            str(adapter), str(engine)
        ]
        res = subprocess.run(argv, capture_output=True, text=True, timeout=60)
        if res.returncode:
            raise RuntimeError(res.stdout + res.stderr)
        ini = folder / (name + "-run.ini")
        count = measurement.count_steps(
            sim, ini, work / ("step-probe-%s-v1424.ini" % task))
        results.append((task, count))
        print("NATIVE_STEPS register %s %d" % (task, count), flush=True)
    (work / "steps-v1424.tsv").write_text(
        "workload\tsteps\n" +
        "".join("%s\t%d\n" % v for v in results))


if __name__ == "__main__":
    main()
