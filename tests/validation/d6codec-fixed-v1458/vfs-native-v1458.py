#!/usr/bin/env python3
"""Native PDP-6 full VFS/refill and compiled-DXR test of fixed v1458.

Install a single relocated decoder image at 000060, then call through
the real 58-word VFS/direct-buffer adapter. All fixture input and
expected output is derived independently from the v1421 block codec.
This tests the exact fast core and VFS adapter, never two core copies.
"""
import argparse
import importlib.util
from pathlib import Path
import re
import subprocess

ROOT = Path(__file__).resolve().parents[3]


def load(path, name):
    spec = importlib.util.spec_from_file_location(name, path)
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod


GROUP = load(ROOT / "tests/validation/d6codec-fastpath-v1420/"
             "generate-v1420.py", "grouped_v1420")
BLOCK = load(ROOT / "tests/validation/d6codec-block-v1421/"
             "generate-v1421.py", "block_v1421")
ERRORS = load(ROOT / "tests/validation/d6codec-compare-v1422/"
              "generate-errors-v1422.py", "errors_v1422")


def attach_core(fixture, image):
    """Mimic Stage-1: copy same-object core, then invoke normal frontend."""
    contents = fixture.read_text().splitlines()
    assert contents.count("main:") == 1
    index = contents.index("main:") + 1
    contents[index:index] = [
        " movei 1,d6b_image_start_v1458",
        " hrl 1,1",
        " hrri 1,060",
        " blt 1,060+(d6b_image_end_v1458-d6b_image_start_v1458)-1",
    ]
    fixture.write_text("\n".join(contents) + "\n" + image.read_text())


def run(args, name, fixture, adapter, image, stack=False):
    attach_core(fixture, image)
    dest = args.work / ("run-" + name)
    crt = (ROOT / "tests/validation/d6codec-native-v051/"
           "crt_stack_v051.s" if stack else
           ROOT / "tests/validation/daimos-test-crt0-v1.s")
    command = [
        str(args.prefix / "bin/p10run"),
        "--machine", "pdp6", "--mode", "deposit",
        "--exec-mode", "go", "--start", "1000", "--timeout", "55",
        "--workdir", str(dest), "--name", name,
        "--expect", "__test_exit=0",
        str(crt),
        str(fixture), str(adapter),
    ]
    if stack:
        command[command.index("--expect"):command.index("--expect")] = [
            "--examine", "__v051_first_changed"]
    result = subprocess.run(command, capture_output=True, text=True,
                            timeout=85)
    if result.returncode:
        raise RuntimeError("FAILED " + name + "\n" +
                           result.stdout + "\n" + result.stderr)
    if stack:
        report = (dest / (name + ".report.txt")).read_text()
        measured = re.search(
            r"__P10RUN_EXAMINE__ __v051_first_changed[^\n]*\n"
            r"[0-7]+:\s+([0-7]{12})", report)
        if measured is None:
            raise ValueError("stack high-water marker missing")
        used = int(measured.group(1), 8)
        if not (0 < used < 0o100):
            raise ValueError("unexpected stack high-water: %o" % used)
        print("STACK_CANARY_HIGH_WATER", "%o" % used, "words",
              flush=True)
    print("FIXED_VFS_PASS", name, flush=True)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--daimos", required=True, type=Path)
    parser.add_argument("--boot", required=True, type=Path)
    parser.add_argument("--work", required=True, type=Path)
    parser.add_argument("--prefix", required=True, type=Path)
    args = parser.parse_args()
    args.work.mkdir(parents=True, exist_ok=True)
    image = (args.daimos / "system/stand/pdp6/common/"
             "block_decompressor_v1458.inc")
    adapter = (args.daimos / "system/kernel/core/"
               "d6block_vfs_fixed_v1458.s")
    generated = args.work / "generated"
    errors = args.work / "errors"
    generated.mkdir(exist_ok=True)
    errors.mkdir(exist_ok=True)

    for name, raw in {
        "normal": [word for f in sorted(args.boot.glob("*.dxr"))
                   for word in GROUP.dxr.load(f)[:128]][:2560],
        "zeros": [0] * 3810,
        "literal": [((i * 365347) ^ (i << 11)) & ((1 << 36) - 1)
                    for i in range(1920)],
        "overlap": [0o123456701234] * 2033,
        "worst": [0o12345] * 1500,
    }.items():
        if name == "worst":
            packed = [BLOCK.command(0, 1), raw[0]] + [
                BLOCK.command(2, 1, 1)] * (len(raw) - 1)
        else:
            packed = BLOCK.encode(raw)
        assert BLOCK.decode(packed, len(raw)) == raw
        modes = [("verify", ())]
        if name == "overlap":
            modes.append(("refill", (1, 7, 32)))
        elif name in ("normal", "literal"):
            modes.append(("refill", (7,)))
        for mode, refills in modes:
            fixture = generated / (name + "_" + mode + "_v1458.s")
            GROUP.emit(fixture, raw, packed, True, refills, version="v1458")
            run(args, name + "_" + mode, fixture, adapter, image)

    # Reuse the existing malformed-input generator without editing source.
    import sys
    old_argv = sys.argv
    try:
        sys.argv = ["generate-errors-v1422.py", str(errors)]
        ERRORS.main()
    finally:
        sys.argv = old_argv
    for source in sorted(errors.glob("block_*_v1422.s")):
        name = source.stem.replace("_v1422", "")
        if name == "block_overlap_buffer":
            continue  # caller-owned nonaliasing invariant, not corrupt file
        fixture = generated / (name + "_v1458.s")
        fixture.write_text(source.read_text().replace("v1421", "v1458"))
        run(args, name, fixture, adapter, image)

    for name in ("kcore", "d6fs-mres", "monitorfs-mres",
                 "swap-mres-v481", "tape-mres"):
        raw = list(GROUP.dxr.load(args.boot / (name + ".dxr")))
        packed = BLOCK.encode(raw)
        assert BLOCK.decode(packed, len(raw)) == raw
        fixture = generated / (name + "_full_v1458.s")
        GROUP.emit(fixture, raw, packed, True, (), version="v1458")
        run(args, name + "_full", fixture, adapter, image)
    raw = [0o123456701234] * 320
    packed = BLOCK.encode(raw)
    fixture = generated / "stack_v1458.s"
    GROUP.emit(fixture, raw, packed, True, (), version="v1458")
    run(args, "stack_canary", fixture, adapter, image, stack=True)
    print("PASS v1458: eight valid refill/direct, nine malformed,"
          " five full-DXR and one stack-canary fixed-low-core VFS tests")


if __name__ == "__main__":
    main()
