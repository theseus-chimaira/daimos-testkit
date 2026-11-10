#!/usr/bin/env python3
"""Observe the first failing EXEC/RUN path of a real TSFS-root boot.

No guest/source code is changed. Stage-1 and the kernel execute normally
from isolated copies of the boot media until a SIMH software breakpoint
is reached, then the simulator prints a register/history snapshot.
"""
import argparse
import importlib.util
from pathlib import Path
import re
import subprocess

ROOT = Path(__file__).resolve().parents[3]
src = ROOT / "tests/validation/d6codec-shell-live-v1426/capture-v1426.py"
spec = importlib.util.spec_from_file_location("capture_v1426", src)
capture = importlib.util.module_from_spec(spec)
spec.loader.exec_module(capture)

LOCALS = ("exec_load_fail", "exec_load_fail_result", "exec_load_vm_fail",
          "exec_load_nomem")
OTHERS = ("proc_run_exec_bad", "proc_run_bad", "proc_run_startup_failed")


def read_symbols(path):
    found = {}
    for line in path.read_text().splitlines():
        fields = line.split()
        if len(fields) >= 2 and re.fullmatch("[0-7]+", fields[-1]):
            found[fields[0]] = int(fields[-1], 8)
    return found


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--boot", type=Path, required=True)
    ap.add_argument("--prefix", type=Path, required=True)
    ap.add_argument("--output", type=Path, required=True)
    ap.add_argument("--timeout", type=int, default=80)
    args = ap.parse_args()
    args.output.mkdir(parents=True, exist_ok=True)
    labels = args.output / "exec-labels-v1461.txt"
    obj = args.output / "exec-v1461.dobj"
    subprocess.run([
        str(args.prefix / "bin/das"), "-F", "-C", "-L", str(labels),
        "-O", str(obj), str(args.boot / "kcore-asm/exec.s")], check=True)
    local = read_symbols(labels)
    linked = read_symbols(args.boot / "kcore.map")
    if "exec_load_process" not in local or "exec_load_process" not in linked:
        raise ValueError("missing EXEC entry symbol")
    bias = linked["exec_load_process"] - local["exec_load_process"]
    stops = {name: local[name] + bias for name in LOCALS}
    stops.update({name: linked[name] for name in OTHERS})
    (args.output / "breakpoints-v1461.txt").write_text(
        "".join("%s %06o\n" % (name, pc)
                for name, pc in sorted(stops.items())))

    ini, _ = capture.isolate_media(args.boot / "boot.ini",
                                   args.output / "isolated-media")
    script = ini.read_text()
    script = script.replace("attach -q dcs0 1101", "attach -q dcs0 22610")
    script = script.replace("attach -q ge0 1201", "attach -q ge0 22620")
    commands = ["set cpu history=512"]
    commands.extend("break %06o" % pc for pc in sorted(set(stops.values())))
    commands.append("go 020")
    commands.extend(["ex PC", "ex 00", "ex 01", "ex 02", "ex 03",
                     "ex 04", "ex 05", "ex 010", "ex 011", "ex 012",
                     "ex 013", "ex 014", "ex 015", "ex 016", "ex 017",
                     "show cpu history=80", "exit"])
    if script.count("go 020") != 1:
        raise ValueError("unexpected boot script layout")
    script = script.replace("go 020", "\n".join(commands))
    ini.write_text(script)
    proc = subprocess.run([str(args.prefix / "bin/pdp6"), str(ini)],
                          stdin=subprocess.DEVNULL, capture_output=True,
                          text=True, errors="replace", timeout=args.timeout)
    (args.output / "simh-break-v1461.log").write_text(proc.stdout + proc.stderr)
    print("TRACE_V1461_BREAKPOINTS", str(args.output / "breakpoints-v1461.txt"))
    print("TRACE_V1461_EXIT", proc.returncode)
    print((proc.stdout + proc.stderr)[-14000:])


if __name__ == "__main__":
    main()
