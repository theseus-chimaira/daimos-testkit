#!/usr/bin/env python3
"""Check both staged physical-memory profiles and no BSS increase."""
import pathlib
import struct
import sys

if len(sys.argv) != 2:
    raise SystemExit("usage: inspect-v1364.py GENERATED_ROOT")
base = pathlib.Path(sys.argv[1])


def sizes(path):
    content = path.read_bytes()
    assert len(content) % 8 == 0 and len(content) >= 16, path
    words = struct.unpack('<' + 'Q' * (len(content) // 8), content)
    assert all(word < (1 << 36) for word in words)
    text = words[1] >> 18
    bss = words[1] & 0o777777
    assert len(words) == 2 + text + ((text + 35) // 36), path
    return text, bss


print("profile\tloader\tv1363_text\tv1364_text\tadditional\tbss")
for core in ("0100000", "01000000"):
    directory = base / ("core_" + core)
    for kind in ("dsk", "drm", "dtc", "mtc", "ptr"):
        oldtext, oldbss = sizes(directory / ("stage1-%s-v1363.dxr" % kind))
        newtext, newbss = sizes(directory / ("stage1-%s-v1364.dxr" % kind))
        assert oldbss == newbss, (kind, core, "BSS growth")
        assert newtext > oldtext
        assert 0o60 + newtext + newbss < 0o20000, (kind, core)
        labels = directory / ("stage1-%s-v1364.labels" % kind)
        symbols = {}
        for row in labels.read_text().splitlines():
            part = row.split()
            if len(part) == 2:
                symbols[part[0]] = int(part[1], 8)
        assert symbols.get("__start") == 0
        assert "d6stage_geometry_v1364" in symbols
        assert "d6codec_v053_decode" in symbols
        print("%s\t%s\t%d\t%d\t%d\t%d" %
              (core, kind, oldtext, newtext, newtext - oldtext, newbss))
print("PASS v1364: ten staged header-guard binaries fit low core without BSS growth")
