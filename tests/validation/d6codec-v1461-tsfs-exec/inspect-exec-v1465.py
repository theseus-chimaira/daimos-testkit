#!/usr/bin/env python3
"""Inspect a real TSFS-root external EXEC stall in isolated SIMH media.

This is a diagnostic, not an acceptance test. It never changes the source
tree or existing writable boot media. Use after strict boot-v1461 failure.
"""
import argparse
import importlib.util
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]
CAPTURE_PATH = (ROOT / "tests/validation/d6codec-shell-live-v1426/"
                "capture-v1426.py")
spec = importlib.util.spec_from_file_location("capture_v1426", CAPTURE_PATH)
capture = importlib.util.module_from_spec(spec)
spec.loader.exec_module(capture)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--boot", required=True, type=Path)
    ap.add_argument("--prefix", required=True, type=Path)
    ap.add_argument("--output", required=True, type=Path)
    ap.add_argument("--interval", type=int, default=75)
    ap.add_argument("--dcs-port", type=int, default=23531)
    ap.add_argument("--ge-port", type=int, default=23532)
    args = ap.parse_args()
    args.output.mkdir(parents=True, exist_ok=True)
    ini, _ = capture.isolate_media(args.boot / "boot.ini",
                                    args.output / "isolated-media")
    lines = ini.read_text().splitlines()
    for i, line in enumerate(lines):
        if line.startswith("attach -q dcs0 "):
            lines[i] = "attach -q dcs0 " + str(args.dcs_port)
        elif line.startswith("attach -q ge0 "):
            lines[i] = "attach -q ge0 " + str(args.ge_port)
    script = "\n".join(lines) + "\n"
    if script.count("go 020") != 1:
        raise ValueError("unexpected simulator GO entry in isolated boot")
    script = script.replace("go 020", "set cpu history=512\ngo 020")
    ini.write_text(script)
    console = capture.Console(args.prefix / "bin/pdp6", ini, args.output)
    try:
        console.take("LOGIN: ", 240)
        console.send("ROOT\r")
        console.take("DSH V1", 120)
        console.take("# ", 80)
        print("V1465_TSFSEXEC_DSH_READY", flush=True)
        console.send("ECHO V1465EXECINSPECT\r")
        try:
            result = console.take("# ", args.interval)
            print("V1465_TSFSEXEC_RETURN", repr(result[-140:]), flush=True)
        except TimeoutError:
            print("V1465_TSFSEXEC_UNRETURNED", args.interval, flush=True)
        print("V1465_DEBUG_PROMPT", repr(console.stop()[-100:]), flush=True)
        for command in ("ex PC", "ex 00", "ex 01", "ex 02", "ex 03",
                        "ex 04", "ex 05", "ex 06", "ex 07", "ex 010",
                        "ex 011", "ex 012", "ex 013", "ex 014",
                        "ex 015", "ex 016", "ex 017",
                        "show cpu history=128"):
            print("V1465_SIMH", command, flush=True)
            print(console.command(command, 20), flush=True)
    finally:
        console.close()


if __name__ == "__main__":
    main()
