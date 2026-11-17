#!/usr/bin/env python3
"""Original-source matched PDP-6 32K KINIT capacity gate.

The current 32K image must be rejected by the original mkimage
stack/core limit even with PURE OFF. This is a negative build
acceptance and NEVER a physical 32K runtime claim.
"""

from pathlib import Path
import re
import sys


def symbols(path):
    data = {}
    for line in Path(path).read_text(encoding="ascii").splitlines():
        cols = line.split()
        if len(cols) > 1 and re.fullmatch(r"[0-7]+", cols[1]):
            data[cols[0]] = int(cols[1], 8)
    return data


def check(on_map, off_map, on_core, off_core, on_stream, off_stream,
          on_log, off_log):
    on = symbols(on_map)
    off = symbols(off_map)
    root_on = Path(on_core).read_bytes()
    root_off = Path(off_core).read_bytes()
    stream_on = Path(on_stream).read_bytes()
    stream_off = Path(off_stream).read_bytes()
    assert root_on == root_off, "KCORE symbol map changed across PURE selection"
    assert stream_on == stream_off, "permanent KCORE bytes changed"
    assert on["__kcore_low_end"] == off["__kcore_low_end"] == 0o24253
    assert "proc_pure_mres_package_v1612" in on
    assert "proc_pure_mres_package_v1612" not in off
    for symbol in ("dtfs_mres_package", "proc_swap_mres_package_v481",
                   "monitorfs_mres_package"):
        assert symbol in on and symbol in off, symbol
    on_end = on["__kinit_image_end"]
    off_end = off["__kinit_image_end"]
    core = 0o100000
    stack = 0o400
    max_end = core - stack
    assert max_end == 0o77400
    assert on_end == 0o113621
    assert off_end == 0o110052
    assert on_end > off_end > core > max_end
    assert on_end - off_end == 0o3547 == 1895
    assert on_end - core == 6033
    assert off_end - core == 4138
    assert on_end - max_end == 6289
    assert off_end - max_end == 4394

    for log, end in ((on_log, on_end), (off_log, off_end)):
        text = Path(log).read_text(encoding="ascii")
        expected = (
            "mkimage: KINIT image end %o exceeds stack-safe limit %o "
            "by %o words (core %o, reserve %o)" %
            (end, max_end, end - max_end, core, stack))
        assert text.count(expected) == 1, (log, "missing genuine mkimage refusal")
        assert text.count(
            "mkimage: KINIT image leaves less than the configured stack reserve"
        ) == 1
        assert "make: ***" in text, "build must fail before boot media"

    print("v1653: original 32K KCORE symbol/stream identity verified, low end 024253")
    print("v1653: OFF KINIT end 110052, exceeds physical core by 4138, safe limit by 4394")
    print("v1653: ON  KINIT end 113621, exceeds physical core by 6033, safe limit by 6289")
    print("v1653: opt-in PURE adds exactly 03547 octal = 1895 decimal transient words")
    print("PASS v1653: original 32K KINIT ON/OFF fail-closed capacity diagnosis")


if __name__ == "__main__":
    if len(sys.argv) != 9:
        raise SystemExit(
            "usage: audit-capacity-v1653.py on-map off-map "
            "on-core off-core on-stream off-stream on-build-log off-build-log")
    try:
        check(*sys.argv[1:])
    except (AssertionError, KeyError, UnicodeError, ValueError, OSError) as err:
        print("FAIL v1653 32K KINIT capacity audit: %s" % err,
              file=sys.stderr)
        sys.exit(1)
