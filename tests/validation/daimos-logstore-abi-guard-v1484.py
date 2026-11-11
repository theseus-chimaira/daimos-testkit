#!/usr/bin/env python3
"""Check the public LOGSTORE auxiliary I/O ABI against installed targets.

The LOGSTORE MRES direct path supplies AC1=unit, AC2=physical block,
AC3=core buffer. Raw physical-driver MRES exports instead consume
AC1=hardware address, AC2=core buffer. Only KCORE block bridges can
correctly translate those arguments.
"""
from pathlib import Path
import re
import sys


def main():
    if len(sys.argv) != 3:
        raise SystemExit("usage: daimos-logstore-abi-guard-v1484.py module_minit.c logstore_runtime.s")
    init = Path(sys.argv[1]).read_text()
    runtime = Path(sys.argv[2]).read_text()
    start = init.index("void\nlogstore_minit(void)")
    end = init.index("\n#endif", start)
    body = init[start:end]
    for driver in ("drm236", "dsk270"):
        for operation in ("read", "write"):
            required = "&%s_%s_%s" % (
                driver,
                operation,
                "block" if driver == "drm236" else "sector",
            )
            if required not in body:
                raise SystemExit("v1484 FAIL: missing KCORE bridge " + required)
    if not re.search(r"logstore_io_direct:.*?hrrz\s+2,6.*?add\s+2,1.*?hlrz\s+1,6.*?subi\s+1,1.*?move\s+3,4",
                     runtime, re.S):
        raise SystemExit("v1484 FAIL: LOGSTORE direct-call register ABI changed")
    if not re.search(r"LOGSTORE_X_WRITE_JUMP\), write_addr\);", body, re.S):
        raise SystemExit("v1484 FAIL: LOGSTORE write target not patched")
    print("PASS v1484: LOGSTORE direct MRES uses unit/block/buffer KCORE bridges")


if __name__ == "__main__":
    main()
