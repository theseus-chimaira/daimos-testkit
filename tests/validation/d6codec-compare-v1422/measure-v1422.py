#!/usr/bin/env python3
"""PDP-6 simulator instruction-step brackets for verified decoders.

SIMH BLT is one retired instruction but copies multiple 36-bit words.
These are NOT PDP-6 clock cycles or measured hardware wall time.
"""
import os
from pathlib import Path
import re
import subprocess
import sys


def one_count(sim, content, n, script):
    script.write_text(re.sub(r"(?m)^step [0-9]+$", "step %d" % n, content))
    proc = subprocess.run([str(sim), "-q", str(script)],
                          capture_output=True, text=True, timeout=40)
    if proc.returncode or "Goodbye" not in proc.stdout:
        raise RuntimeError("SIMH failure during step count: " + proc.stdout)
    if "Step expired" in proc.stdout:
        return False
    if "HALT instruction" not in proc.stdout:
        raise RuntimeError("missing HALT or STEP status: " + proc.stdout)
    if "000000000000\nGoodbye" not in proc.stdout:
        raise RuntimeError("decoder returned failure")
    return True


def count_steps(sim, run_ini, outfile):
    original = run_ini.read_text()
    assert re.search(r"(?m)^step [0-9]+$", original)
    limit = 1000000
    if not one_count(sim, original, limit, outfile):
        raise RuntimeError("native test exceeds step budget")
    lo, hi = 0, limit
    while hi - lo > 1:
        mid = (lo + hi) // 2
        if one_count(sim, original, mid, outfile):
            hi = mid
        else:
            lo = mid
    return hi


def run_fixture(work, testkit, daimos, sim, name, task):
    if name == "baseline":
        fixture = work / "grouped" / ("%s_bench_v1420.s" % task)
        engine = work / "d6codec_stream_baseline_v1422.s"
        adapter = work / "d6codec_vfs_baseline_v1422.s"
    elif name == "grouped":
        fixture = work / "grouped" / ("%s_bench_v1420.s" % task)
        engine = daimos / "system/kernel/core/d6codec_stream_v1420.s"
        adapter = daimos / "system/kernel/core/d6codec_vfs_v1420.s"
    else:
        fixture = work / "block" / ("%s_bench_v1421.s" % task)
        engine = daimos / "system/kernel/core/d6codec_block_stream_v1421.s"
        adapter = daimos / "system/kernel/core/d6codec_block_vfs_v1421.s"
    crt = testkit / "tests/validation/daimos-test-crt0-v1.s"
    path = work / ("step-%s-%s" % (name, task))
    cmd = [
        str(Path.home() / "cross/bin/p10run"),
        "--machine", "pdp6", "--mode", "deposit",
        "--exec-mode", "step", "--step-limit", "1000000",
        "--start", "1000", "--timeout", "40",
        "--workdir", str(path),
        "--name", "step-%s-%s-v1422" % (name, task),
        "--expect", "__test_exit=0", str(crt), str(fixture),
        str(adapter), str(engine)
    ]
    result = subprocess.run(cmd, capture_output=True, text=True, timeout=60)
    if result.returncode:
        raise RuntimeError(result.stdout + result.stderr)
    ini = path / ("step-%s-%s-v1422-run.ini" % (name, task))
    return count_steps(sim, ini,
                       work / ("step-probe-%s-%s-v1422.ini" % (name, task)))


def main():
    work, testkit, daimos = (Path(arg).resolve() for arg in sys.argv[1:])
    sim = Path.home() / "cross/bin/pdp6"
    rows = []
    # Choose the codec hot-path classes and matched output lengths.
    for task in ("zeros", "normal", "literal", "overlap", "worst"):
        for name in ("baseline", "grouped", "block"):
            steps = run_fixture(work, testkit, daimos, sim, name, task)
            print("NATIVE_STEPS %s %s %d" % (name, task, steps),
                  flush=True)
            rows.append((name, task, steps))
    (work / "steps-v1422.tsv").write_text(
        "codec\tworkload\tsteps\n" +
        "".join("%s\t%s\t%d\n" % row for row in rows))
    print("WROTE", work / "steps-v1422.tsv", flush=True)


if __name__ == "__main__":
    main()
