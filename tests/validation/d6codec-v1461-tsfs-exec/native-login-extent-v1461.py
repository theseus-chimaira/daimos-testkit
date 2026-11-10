#!/usr/bin/env python3
"""Decode LOGIN's actual last TSFS restart extent on a native PDP-6.

Use the compressed words read from the real TSFS DECtape member,
not a Python-recompressed approximation. Compare against the
corresponding final words of the actual linked LOGIN DXR file.
"""
import argparse
import importlib.util
from pathlib import Path
import struct
from types import SimpleNamespace

ROOT = Path(__file__).resolve().parents[3]
src = ROOT / "tests/validation/d6codec-fixed-v1458/vfs-native-v1458.py"
spec = importlib.util.spec_from_file_location("vfs_native_v1458", src)
vfs_native = importlib.util.module_from_spec(spec)
spec.loader.exec_module(vfs_native)


def words_from_tsfs(path):
    data = path.read_bytes()
    halfs = struct.unpack("<%dI" % (len(data) // 4), data)
    return [(a << 18) | b for a, b in zip(halfs[::2], halfs[1::2])]


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--daimos", required=True, type=Path)
    ap.add_argument("--boot", required=True, type=Path)
    ap.add_argument("--prefix", required=True, type=Path)
    ap.add_argument("--work", required=True, type=Path)
    args = ap.parse_args()
    args.work.mkdir(parents=True, exist_ok=True)
    media = words_from_tsfs(args.boot / "media/tsfs-root0.dta")
    tdir = media[3 * 128:4 * 128]
    extent_start = tdir[13] & 0o777777
    login_extent = 163  # FILE/LOGIN last restart in v1459 TSFS fixture
    record = media[(extent_start * 128) + login_extent * 4:
                   (extent_start * 128) + login_extent * 4 + 4]
    if len(record) != 4 or record[0] != 12 * 256 or record[2] != 0o1000001:
        raise ValueError("source media layout changed; rederive LOGIN index")
    block = record[1] & 0o777777
    payload = media[block * 128:(block + 1) * 128]
    count = payload[1]
    decoded = payload[0]
    if not 1 <= count <= 126 or decoded != 149:
        raise ValueError("unexpected LOGIN compressed restart header")
    packed = payload[2:2 + count]

    login = args.boot / "userland-build/userland/login.dxr"
    data = login.read_bytes()
    actual = struct.unpack("<%dQ" % (len(data) // 8), data)
    original = list(actual[-decoded:])
    if vfs_native.BLOCK.decode(packed, decoded) != original:
        raise ValueError("host TSFS compressed restart differs from LOGIN DXR")
    print("HOST_REAL_TSFS_EXTENT_PASS", "decoded", decoded,
          "packed", len(packed), flush=True)

    fixture = args.work / "login-final-extent-v1461.s"
    vfs_native.GROUP.emit(fixture, original, packed, True, (),
                          version="v1458")
    run_args = SimpleNamespace(daimos=args.daimos, boot=args.boot,
                               prefix=args.prefix, work=args.work)
    image = (args.daimos / "system/stand/pdp6/common/"
             "block_decompressor_v1458.inc")
    adapter = (args.daimos / "system/kernel/core/"
               "d6block_vfs_fixed_v1458.s")
    vfs_native.run(run_args, "real_tsfs_login_last_extent", fixture,
                   adapter, image)
    print("PASS real LOGIN TSFS compressed restart in native PDP-6")


if __name__ == "__main__":
    main()
