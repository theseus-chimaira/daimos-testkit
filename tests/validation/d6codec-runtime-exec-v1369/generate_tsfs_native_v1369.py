#!/usr/bin/env python3
"""Exercise the unchanged TSFS restart read/copy/free on grouped data."""
import importlib.util
import pathlib
import sys


def reference():
    testkit = pathlib.Path(__file__).resolve().parents[3]
    path = testkit / "tests/validation/d6codec-current-corpus-v1359/generate-v1359.py"
    spec = importlib.util.spec_from_file_location("host_grouped_v1359", path)
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod


def generate(source, target, invalid):
    # 256-word TSFS restart extent. The first 32 words repeat thereafter;
    # offset 010..027 equals 03010..03027, as in the legacy native oracle.
    decoded = [0o3000 + i % 0o40 for i in range(0o400)]
    ref = reference()
    packed = ref.encode(decoded)
    if ref.reference.decode(packed, len(decoded)) != decoded:
        raise ValueError("host grouped TSFS restart roundtrip failure")
    if not 0 < len(packed) <= 0o176:
        raise ValueError("grouped TSFS restart does not fit one DTC block")
    if invalid:
        packed[0] = 0               # invalid zero-token control

    text = pathlib.Path(source).read_text()
    original = text.index("d6lz36_decode_core:\n")
    end = text.index("; The direct-buffer D6LZ test", original)
    text = text[:original] + text[end:]
    text = text.replace("        .globl d6lz36_decode_core\n", "")
    original = text.index("dtc_data:\n")
    end = text.index("; mm_alloc fifth argument", original)
    media = """dtc_data:
        caie 1,4
        jrst kret_neg1
        caie 2,6
        jrst kret_neg1
        push 17,3
        pushj 17,clear_block
        pop 17,3
        movei 5,0
restart_copy_v1369:
        move 4,grouped_restart_v1369(5)
        movem 4,0(3)
        aoj 3,
        aoj 5,
        caige 5,0%o
        jrst restart_copy_v1369
        setz 1,
        popj 17,

""" % (len(packed) + 2)
    text = text[:original] + media + text[end:]
    if invalid:
        anchor = "        caie    1,020\n        jrst    fail_count\n"
        if text.count(anchor) != 1:
            raise ValueError("TSFS oracle success check moved")
        error = """        jumpl   1,failure_checked_v1369
        jrst    fail_count
failure_checked_v1369:
        move 5,alloc_state
        caie 5,2
        jrst fail_free
        setz 1,
        popj 17,
"""
        text = text.replace(anchor, error, 1)
    anchor = "        .data\ndtfs_media_base:"
    if text.count(anchor) != 1:
        raise ValueError("TSFS oracle data section moved")
    words = "".join("        .word 0%o\n" % x for x in [0o400, len(packed)] + packed)
    text = text.replace(anchor, "        .data\ngrouped_restart_v1369:\n" + words +
                        "dtfs_media_base:", 1)
    pathlib.Path(target).write_text(text)
    print("GROUPED_TSFS_V1369 words=%d compressed=%d invalid=%s" %
          (len(decoded), len(packed), invalid))


if __name__ == "__main__":
    if len(sys.argv) != 4:
        raise SystemExit("usage: generate_tsfs_native_v1369.py OLD_TSFS_ORACLE OUT.s good|bad")
    if sys.argv[3] not in ("good", "bad"):
        raise SystemExit("mode must be good or bad")
    generate(sys.argv[1], sys.argv[2], sys.argv[3] == "bad")
