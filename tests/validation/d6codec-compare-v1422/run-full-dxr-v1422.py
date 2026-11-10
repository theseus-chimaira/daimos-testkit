#!/usr/bin/env python3
"""Full native PDP-6 DXR tests for both experimental decoders.

The 29-file host corpus is checked by the host codec generators.
This runner verifies all output words on five representative real
DXRs with the actual native assembler, not just their 128-word prefix.
"""
import argparse
import importlib.util
from pathlib import Path
import subprocess

ROOT = Path(__file__).resolve().parents[3]


def load_module(name, path):
    spec = importlib.util.spec_from_file_location(name, path)
    obj = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(obj)
    return obj


grouped = load_module(
    "grouped_v1420",
    ROOT / "tests/validation/d6codec-fastpath-v1420/generate-v1420.py")
block = load_module(
    "block_v1421",
    ROOT / "tests/validation/d6codec-block-v1421/generate-v1421.py")


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("dxr_dir", type=Path)
    parser.add_argument("daimos", type=Path)
    parser.add_argument("work", type=Path)
    args = parser.parse_args()
    args.work.mkdir(parents=True, exist_ok=True)
    crt = ROOT / "tests/validation/daimos-test-crt0-v1.s"
    p10run = Path.home() / "cross/bin/p10run"
    representatives = (
        "kcore", "d6fs-mres", "monitorfs-mres",
        "swap-mres-v481", "tape-mres")
    for file in representatives:
        source = list(grouped.dxr.load(args.dxr_dir / (file + ".dxr")))
        for codec, module, version, engine_name, adapter_name in (
            ("grouped", grouped, "v1420", "d6codec_stream_v1420.s",
             "d6codec_vfs_v1420.s"),
            ("block", block, "v1421", "d6codec_block_stream_v1421.s",
             "d6codec_block_vfs_v1421.s"),
            ("register", block, "v1424", "d6codec_block_core_v1424.s",
             "d6codec_block_vfs_v1424.s")
        ):
            packed = module.encode(source)
            if codec in ("block", "register") and block.decode(
                    packed, len(source)) != source:
                raise RuntimeError("block host roundtrip failed")
            fixture = args.work / (
                "%s_%s_full_v1422.s" % (codec, file))
            grouped.emit(fixture, source, packed, True, (), version=version)
            run = args.work / ("run-%s-%s" % (codec, file))
            command = [
                str(p10run), "--machine", "pdp6", "--mode", "deposit",
                "--exec-mode", "go", "--start", "1000",
                "--timeout", "45", "--workdir", str(run),
                "--name", "d6codec-full-%s-%s-v1422" % (codec, file),
                "--expect", "__test_exit=0", str(crt), str(fixture),
                str(args.daimos / "system/kernel/core" / adapter_name),
                str(args.daimos / "system/kernel/core" / engine_name)
            ]
            result = subprocess.run(
                command, capture_output=True, text=True, timeout=65)
            if result.returncode:
                raise RuntimeError(result.stdout + result.stderr)
            print("FULL_DXR_NATIVE_PASS %s %s raw=%d encoded=%d" %
                  (codec, file, len(source), len(packed)), flush=True)
    print("PASS fifteen native full-DXR codec runs v1422/v1424")


if __name__ == "__main__":
    main()
