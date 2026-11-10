#!/usr/bin/env python3
"""Native PDP-6 full initialized-DXR decode with v1436, exact byte checking."""
import importlib.util
from pathlib import Path
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[3]
source = ROOT / "tests/validation/d6codec-compare-v1422/run-full-dxr-v1422.py"
spec = importlib.util.spec_from_file_location("full_v1422", source)
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)


def main():
    dxrs, daimos, output = (Path(x) for x in sys.argv[1:])
    output.mkdir(parents=True, exist_ok=True)
    crt = ROOT / "tests/validation/daimos-test-crt0-v1.s"
    adapter = daimos / "system/kernel/core/d6codec_block_vfs_v1436.s"
    engine = daimos / "system/kernel/core/d6codec_block_core_v1436.s"
    runner = Path.home() / "cross/bin/p10run"
    for name in ("kcore", "d6fs-mres", "monitorfs-mres",
                 "swap-mres-v481", "tape-mres"):
        raw = list(module.grouped.dxr.load(dxrs / (name + ".dxr")))
        encoded = module.block.encode(raw)
        if module.block.decode(encoded, len(raw)) != raw:
            raise ValueError("host decode failure")
        fixture = output / (name + "_full_v1436.s")
        module.grouped.emit(
            fixture, raw, encoded, True, (), version="v1436")
        work = output / ("native-" + name)
        argv = [
            str(runner), "--machine", "pdp6", "--mode", "deposit",
            "--exec-mode", "go", "--start", "1000", "--timeout", "50",
            "--workdir", str(work), "--name", name + "-full-v1436",
            "--expect", "__test_exit=0", str(crt),
            str(fixture), str(adapter), str(engine)]
        result = subprocess.run(
            argv, capture_output=True, text=True, timeout=80)
        if result.returncode:
            raise RuntimeError(result.stdout + result.stderr)
        print("FULL_DXR_PASS", name, len(raw), len(encoded), flush=True)


if __name__ == "__main__":
    main()
