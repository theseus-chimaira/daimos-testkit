#!/usr/bin/env python3
"""Extract actual KCORE v1538 root I/O gate and v1515 fatal leaf.

Older standalone TSFS native tests link the complete optional provider but
do not build fixed KCORE. Extract the exact source, not a test reimplementation,
so their existing IO-success or negative-case assertions remain meaningful.
"""
from pathlib import Path
import sys


def main():
    if len(sys.argv) != 3:
        raise SystemExit("usage: extractor DAIMOS_REPO OUTPUT_ASSEMBLY")
    repo = Path(sys.argv[1])
    output = Path(sys.argv[2])
    src = (repo / "system/kernel/proc/proc_storage_runtime_v30.s").read_text()
    start = "kcore_root_fs_io_failure_v1538:\n"
    assert src.count(start) == 1
    body = src[src.index(start):]
    assert body.count("kcore_critical_device_lost_v1515:") == 1
    assert body.count("halt    .") == 3
    output.write_text(
        ".text\n.globl kcore_root_fs_io_failure_v1538\n"
        ".globl kcore_critical_device_lost_v1515\n" + body)


if __name__ == "__main__":
    main()
