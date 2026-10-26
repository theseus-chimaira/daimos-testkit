#!/usr/bin/env python3
"""Guard the minimal caller-owned TSFS READDIR child projection."""
import pathlib
import re
import sys

source = (pathlib.Path(sys.argv[1]) / "system/kernel/fs/tsfs_runtime.s").read_text()
start = source.index("tsfs_readdir:\n")
end = source.index("tsfs_readdir_eof:\n", start)
block = source[start:end]
required = (
    r"pushj\s+17,tsfs_file_record",
    r"hrrz\s+011,\(1\)",
    r"andi\s+011,3",
    r"addi\s+1,1",
    r"move\s+2,012",
    r"pushj\s+17,vfs_name_from_words",
    r"movem\s+4,5\(012\)",
)
for pattern in required:
    if not re.search(pattern, block):
        raise SystemExit(f"FAIL missing READDIR projection: {pattern}")
print("tsfs-readdir-projection-v430: PASS (type and name copied to caller-owned result)")
