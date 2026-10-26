#!/usr/bin/env python3
"""Guard shared-transfer-buffer liveness across blocking I/O veneers.

This checks selected *actual* source paths, not concurrent scheduling.
The producer/consumer pairs must be reexamined before changing the lock.
"""
import pathlib
import re
import sys


def body(path, first, last):
    source = path.read_text()
    match = re.search(rf"(?ms)^{re.escape(first)}:\s*\n(.*?)^{re.escape(last)}:", source)
    if match is None:
        raise SystemExit(f"missing routine span {path.name}: {first}..{last}")
    return match.group(1)


def require(block, pattern, label):
    if not re.search(pattern, block):
        raise SystemExit(f"missing {label}")


def main():
    root = pathlib.Path(sys.argv[1]).resolve() / "system/kernel"
    d6 = (root / "fs/d6fs_runtime.s").read_text()
    dt = (root / "fs/dtfs_runtime.s").read_text()
    ts = (root / "fs/tsfs_runtime.s").read_text()
    for text, call, name in (
        (d6, "fs_backing_read", "D6FS read"),
        (d6, "fs_backing_write", "D6FS write"),
        (ts, "dtfs_dtc_read", "TSFS read"),
        (dt, "dtfs_dtc_write", "DTFS write"),
    ):
        require(text, rf"(?ms)^\s*movei\s+3,fs_block_workspace[^\n]*\n"
                      rf"\s*pushj\s+17,{call}\b", name + " shared-buffer I/O")
    veneer = body(root / "fs/dtfs_runtime.s", "dtfs_dtc_read", "dtfs_dtc_read_jump")
    require(veneer, r"pushj\s+17,dtfs_dtc_read_jump", "DTC driver veneer")
    require(veneer, r"pushj\s+17,bcache_store", "DTC cache publication")
    require((root / "drivers/tape_io.s").read_text(),
            r"pushj\s+017,proc_wait_event", "tape can sleep")
    require((root / "drivers/dsk_io.s").read_text(),
            r"pushj\s+017,proc_wait_event", "disk can sleep")
    require((root / "drivers/drm236_io.s").read_text(),
            r"pushj\s+017,proc_wait_event", "drum can sleep")
    print("provider-io-lifetime-v427: PASS (shared buffer spans physical I/O; lock required)")


if __name__ == "__main__":
    main()
