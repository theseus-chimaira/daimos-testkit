#!/usr/bin/env python3
"""Check fixed D6CODEC decoder geometry in a real linked KCORE map.

Recovers the original v1459 detached symbol audit. Complements the
existing byte-exact Stage-1/KCORE image comparison; does not replace it.
"""

import argparse
from pathlib import Path
import re
import sys


def symbols_from_map(contents):
    result = {}
    for line in contents.splitlines():
        fields = line.split()
        if len(fields) == 2 and re.fullmatch(r"[0-7]+", fields[1]):
            assert fields[0] not in result, "duplicate map symbol " + fields[0]
            result[fields[0]] = int(fields[1], 8)
    return result


def validate(symbols):
    start = symbols["d6codec_block_core_v1458"]
    assert start == 0o60, "block decoder not placed at fixed 000060"
    assert symbols["d6b_image_start_v1458"] == start, \
        "decoder image start does not equal entry"
    assert symbols["d6b_image_end_v1458"] - start == 53, \
        "decoder core no longer occupies exactly 53 words"
    end = start + 53
    assert symbols["d6codec_decode_vfs_v1458"] >= end, \
        "VFS adapter overlaps fixed decoder image"
    assert symbols["d6codec_decode_buffer_v1458"] >= end, \
        "buffer adapter overlaps fixed decoder image"
    assert symbols["__kcore_low_end"] >= end, \
        "KCORE permanent boundary cuts through decoder"
    assert "d6codec_block_core_v1452" not in symbols, \
        "old v1452 decoder core still linked"
    assert "d6codec_decode_vfs_v1452" not in symbols, \
        "old v1452 VFS decoder still linked"


def negative_controls(symbols):
    cases = (
        ("moved-fixed-core", "d6codec_block_core_v1458", 0o61),
        ("expanded-fixed-core", "d6b_image_end_v1458", 0o60 + 54),
        ("overlapped-vfs", "d6codec_decode_vfs_v1458", 0o70),
        ("overlapped-buffer", "d6codec_decode_buffer_v1458", 0o70),
    )
    for label, key, replacement in cases:
        candidate = dict(symbols)
        candidate[key] = replacement
        try:
            validate(candidate)
        except (AssertionError, KeyError):
            print("PASS v1821: rejected " + label)
        else:
            raise AssertionError("accepted unsafe map mutation: " + label)
    candidate = dict(symbols)
    candidate["d6codec_block_core_v1452"] = 0o60
    try:
        validate(candidate)
    except (AssertionError, KeyError):
        print("PASS v1821: rejected duplicate old decoder")
    else:
        raise AssertionError("accepted obsolete v1452 decoder symbol")


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--build", type=Path, required=True,
                        help="source-matched DAIMOS build root")
    args = parser.parse_args()
    path = args.build / "system/boot/pdp6/kcore.map"
    symbols = symbols_from_map(path.read_text(encoding="ascii"))
    validate(symbols)
    print("PASS v1821: linked fixed decoder at 000060, size 53, "
          "VFS %06o, buffer %06o, KCORE boundary %06o" %
          (symbols["d6codec_decode_vfs_v1458"],
           symbols["d6codec_decode_buffer_v1458"],
           symbols["__kcore_low_end"]))
    negative_controls(symbols)


if __name__ == "__main__":
    try:
        main()
    except (AssertionError, KeyError, OSError, UnicodeError) as error:
        sys.exit("FAIL v1821: " + str(error))
