#!/usr/bin/env python3
"""Verify absolute read-in placement and safe Stage-1 memory budget."""
import pathlib
import struct
import sys

if len(sys.argv) != 2:
    raise SystemExit("usage: inspect-v1363.py OUTPUT_DIRECTORY")
base = pathlib.Path(sys.argv[1])


def metadata(path):
    data = path.read_bytes()
    if len(data) < 16 or len(data) % 8:
        raise AssertionError(("bad DXR container", path))
    words = struct.unpack('<' + 'Q' * (len(data) // 8), data)
    for word in words:
        assert not word >> 36, path
    code = words[1] >> 18
    bss = words[1] & 0o777777
    assert len(words) == 2 + code + ((code + 35) // 36), path
    return code, bss


def labels(path):
    result = {}
    for row in path.read_text().splitlines():
        split = row.split()
        if len(split) == 2:
            result[split[0]] = int(split[1], 8)
    return result


print("loader\told_text\tnew_text\tadditional\tbss\tdecoder_address")
for kind in ("dsk", "drm", "dtc", "mtc", "ptr"):
    old, old_bss = metadata(base / ("stage1-%s-original.dxr" % kind))
    new, bss = metadata(base / ("stage1-%s-v1363.dxr" % kind))
    assert bss == old_bss, (kind, "unexpected persistent BSS growth", old_bss, bss)
    symbols = labels(base / ("stage1-%s-v1363.labels" % kind))
    assert symbols["__start"] == 0
    assert "d6lz36_decode_core" not in symbols
    decoder = symbols["d6codec_v053_decode"]
    handoff = symbols["stage1_handoff"]
    assert 0 < decoder < new and 0 < handoff < new
    # Stage-0 loads the read-in at octal 60. Its text, BSS and stack
    # (starting at 020000) must not overlap; KINIT starts at 030000.
    assert 0o60 + new + bss < 0o20000
    assert (base / ("stage1-%s-v1363.pt" % kind)).stat().st_size > 0
    print("%s\t%d\t%d\t%d\t%d\t0%o" %
          (kind, old, new, new - old, bss, 0o60 + decoder))
print("PASS v1363: five linked Stage-1 sources and absolute read-in images")
