#!/usr/bin/env python3
"""Snapshot live PDP-6 Stage-1 registers after a short boot interval.

The simulator is paused with the standard CTY control-E interrupt;
no guest memory or media is patched. It prints PC and the two
Stage-1 progress markers before exiting the simulator cleanly.
"""
import argparse
import importlib.util
from pathlib import Path
import time

ROOT = Path(__file__).resolve().parents[3]
src = ROOT / "tests/validation/d6codec-shell-live-v1426/capture-v1426.py"
spec = importlib.util.spec_from_file_location("capture_v1426", src)
capture = importlib.util.module_from_spec(spec)
spec.loader.exec_module(capture)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--boot", type=Path, required=True)
    ap.add_argument("--prefix", type=Path, required=True)
    ap.add_argument("--output", type=Path, required=True)
    ap.add_argument("--seconds", type=float, default=5.)
    ap.add_argument("--dcs-port", type=int, default=22101)
    ap.add_argument("--ge-port", type=int, default=22102)
    args = ap.parse_args()
    args.output.mkdir(parents=True, exist_ok=True)
    ini, _ = capture.isolate_media(args.boot / "boot.ini",
                                   args.output / "isolated-media")
    text = ini.read_text().replace("attach -q dcs0 1101",
                                   "attach -q dcs0 %d" % args.dcs_port)
    text = text.replace("attach -q ge0 1201",
                        "attach -q ge0 %d" % args.ge_port)
    ini.write_text(text)
    console = capture.Console(args.prefix / "bin/pdp6", ini, args.output)
    try:
        time.sleep(args.seconds)
        out = console.stop()
        for cmd in ("ex PC", "ex 040", "ex 041", "ex 00", "ex 01",
                    "ex 02", "ex 03", "ex 04", "ex 05", "ex 06",
                    "ex 07", "ex 010", "ex 011", "ex 012", "ex 013",
                    "ex 014", "ex 017", "show dtc", "show mtc"):
            try:
                out += "\nCOMMAND " + cmd + "\n" + console.command(cmd)
            except Exception as ex:
                out += "\nFAILED " + cmd + ": " + repr(ex)
        (args.output / "stage1-snapshot-v1460.txt").write_text(out)
        print(out[-10500:])
    finally:
        console.close()


if __name__ == "__main__":
    main()
