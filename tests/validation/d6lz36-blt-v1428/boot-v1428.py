#!/usr/bin/env python3
"""Boot full DAIMOS through a freshly assembled BLT DSK Stage-1.

Uses existing real KINIT/root media copied to a disposable directory.
This checks Stage-1 expansion independently from synthetic D6LZ fixtures.
The installed production KCORE image remains the existing boot image.
"""
import argparse
import importlib.util
from pathlib import Path
import subprocess

ROOT = Path(__file__).resolve().parents[3]
MODULE = ROOT / "tests/validation/d6codec-shell-live-v1426/capture-v1426.py"
spec = importlib.util.spec_from_file_location("capture_v1426", MODULE)
capture = importlib.util.module_from_spec(spec)
spec.loader.exec_module(capture)


def main():
    p = argparse.ArgumentParser()
    p.add_argument("--daimos", required=True, type=Path)
    p.add_argument("--boot", required=True, type=Path)
    p.add_argument("--prefix", required=True, type=Path)
    p.add_argument("--output", required=True, type=Path)
    a = p.parse_args()
    a.output.mkdir(parents=True, exist_ok=True)
    das = a.prefix / "bin/das"
    convert = a.prefix / "bin/dxrconvert"
    asm = a.daimos / "system/stand/pdp6/dsk/stage1.s"
    dxr = a.output / "stage1-dsk-blt-v1428.dxr"
    tape = a.output / "stage1-dsk-blt-v1428.pt"
    subprocess.run(
        [str(das), "-F", "-K", "-O", str(dxr), str(asm)], check=True)
    subprocess.run(
        [str(convert), "--pdp6-readin", "-b", "060",
         str(dxr), str(tape)], check=True)
    with tape.open("ab") as f:
        f.write(b"\252")
    print("BUILT DSK Stage-1 with 39-word v1428 decoder", flush=True)
    ini, manifest = capture.isolate_media(
        a.boot / "boot.ini", a.output / "isolated-boot")
    raw = ini.read_text()
    lines = raw.splitlines()
    altered = 0
    for i, line in enumerate(lines):
        if line.startswith("attach -q ptr "):
            lines[i] = "attach -q ptr " + str(tape)
            altered += 1
    if altered != 1:
        raise ValueError("exactly one real Stage-1 PTR attachment required")
    ini.write_text("\n".join(lines) + "\n")
    simulator = a.prefix / "bin/pdp6"
    console = capture.Console(simulator, ini, a.output)
    try:
        console.take("LOGIN: ", 140)
        print("PASS v1428 DSK Stage-1 -> KINIT -> LOGIN", flush=True)
        console.send("ROOT\r")
        console.take("DSH V1", 80)
        console.take("# ", 60)
        out = console.guest("ECHO BLT1428BOOTPASS")
        if "BLT1428BOOTPASS" not in out:
            raise RuntimeError("guest DSH command did not succeed")
        print("PASS v1428 full real DSK-root boot, DSH login, ECHO",
              flush=True)
    finally:
        console.close()


if __name__ == "__main__":
    main()
