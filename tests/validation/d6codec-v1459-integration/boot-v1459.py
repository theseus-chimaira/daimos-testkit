#!/usr/bin/env python3
"""Cold-boot the real v1459 block-only image from isolated disk media.

No source tree or pre-existing writable boot medium is modified.
The image is the actual Makefile output, not a synthetic decoder fixture.
"""
import argparse
import importlib.util
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]
SOURCE = (ROOT / "tests/validation/d6codec-shell-live-v1426/"
          "capture-v1426.py")
SPEC = importlib.util.spec_from_file_location("capture_v1426", SOURCE)
CAPTURE = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(CAPTURE)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--boot", required=True, type=Path)
    parser.add_argument("--prefix", required=True, type=Path)
    parser.add_argument("--output", required=True, type=Path)
    parser.add_argument("--stage1-tape", type=Path,
                        help="replace only the PTR Stage-1 read-in tape")
    parser.add_argument("--timeout", type=int, default=180)
    parser.add_argument("--dcs-port", type=int, default=21101)
    parser.add_argument("--ge-port", type=int, default=21201)
    args = parser.parse_args()
    args.output.mkdir(parents=True, exist_ok=True)
    ini, media = CAPTURE.isolate_media(args.boot / "boot.ini",
                                       args.output / "isolated-media")
    lines = ini.read_text().splitlines()
    for i, line in enumerate(lines):
        if line.startswith("attach -q dcs0 "):
            lines[i] = "attach -q dcs0 " + str(args.dcs_port)
        elif line.startswith("attach -q ge0 "):
            lines[i] = "attach -q ge0 " + str(args.ge_port)
    if args.stage1_tape:
        matches = [i for i, line in enumerate(lines)
                   if line.startswith("attach -q ptr ")]
        if len(matches) != 1:
            raise ValueError("expected exactly one PTR Stage-1 attachment")
        lines[matches[0]] = "attach -q ptr " + str(args.stage1_tape)
    ini.write_text("\n".join(lines) + "\n")
    print("V1459_ISOLATED_MEDIA", len(media), flush=True)
    console = CAPTURE.Console(args.prefix / "bin/pdp6", ini, args.output)
    try:
        console.take("LOGIN: ", args.timeout)
        print("V1459_COLD_BOOT_LOGIN_PASS", flush=True)
        console.send("ROOT\r")
        console.take("DSH V1", 100)
        console.take("# ", 60)
        print("V1459_DSH_LOGIN_PASS", flush=True)
        result = console.guest("ECHO V1459BLOCKBOOTPASS", timeout=70)
        if "V1459BLOCKBOOTPASS" not in result:
            raise RuntimeError("guest DSH echo command failed")
        print("V1459_DSH_EXEC_PASS", flush=True)
    finally:
        console.close()


if __name__ == "__main__":
    main()
