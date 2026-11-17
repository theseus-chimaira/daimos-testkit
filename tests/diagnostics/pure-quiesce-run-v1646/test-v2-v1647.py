#!/usr/bin/env python3
"""Reject corrupt native DTVOL2 physical RBN0 test witnesses."""

import importlib.util
from pathlib import Path
import sys
import tempfile


def set_word(data, index, word):
    pos = index * 8
    data[pos:pos + 4] = (word >> 18).to_bytes(4, "little")
    data[pos + 4:pos + 8] = (word & 0o777777).to_bytes(4, "little")


def main(media):
    here = Path(__file__).resolve().parent
    spec = importlib.util.spec_from_file_location(
        "check_v2_v1647", here / "check-v2-v1647.py")
    assert spec is not None and spec.loader is not None
    validator = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(validator)
    validator.check(media)
    original = bytearray(media.read_bytes()[:128 * 8])
    assert len(original) == 128 * 8

    mutations = (
        ("legacy-v1", 0, 0o446466575421),
        ("zero-id", 1, 0),
        ("bad-id-check", 3, 0),
        ("dirty", 4, 0o552255225522),
        ("bad-seal", 5, 0),
        ("unexpected-tail", 6, 1),
    )
    with tempfile.TemporaryDirectory(prefix="p1e-v2-v1647-") as tmp:
        test_path = Path(tmp) / "mutated-dtc3-v1647.tap"
        for name, index, value in mutations:
            changed = bytearray(original)
            set_word(changed, index, value)
            test_path.write_bytes(changed)
            try:
                validator.check(test_path)
            except AssertionError:
                continue
            raise AssertionError("accepted invalid media: " + name)
        test_path.write_bytes(original[:8])
        try:
            validator.check(test_path)
        except AssertionError:
            pass
        else:
            raise AssertionError("accepted truncated RBN0")
    print("PASS v1647: seven invalid DTVOL2 physical witnesses rejected")


if __name__ == "__main__":
    if len(sys.argv) != 2:
        raise SystemExit("usage: test-v2-v1647.py dtc3-image")
    main(Path(sys.argv[1]))
