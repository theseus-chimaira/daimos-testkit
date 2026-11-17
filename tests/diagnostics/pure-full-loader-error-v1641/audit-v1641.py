#!/usr/bin/env python3
"""Audit real FULL source/target rollback after a one-shot AC1 injection.

The original compressed-loader call is required to return SUCCESS
before the test-only AC1 register is changed to -1. This proves
the v1391 error branch and owner cleanup, NOT a real VFS I/O fault.
"""

import argparse
from pathlib import Path
import re
import runpy


def audit(kmap, mmap, dxrtext, trace, source, plain, compressed, manifest):
    h = runpy.run_path(str(Path(__file__).resolve().parent.parent /
                           "pure-full-restore-v1638/audit-v1638.py"))
    syms, mres = h["symbols"](kmap), h["symbols"](mmap)
    stage = h["stage"]
    assert mres["proc_pure_ram_restore_v1391"] == 0o2207
    assert mres["exec_image_full_bounded_v1391"] == 0o3224
    base = 0o32026
    callback_return = base + 0o2333
    service_return = base + 0o433
    for offset, word in ((0o2332, "260746000000"),
                         (0o2333, "561400777774"),
                         (0o0432, "260740002207"),
                         (0o0433, "326040000451")):
        assert ("IMAGE  %06o %s" % (offset, word)) in dxrtext
    assert ("%o:\t561400777774" % callback_return) in trace
    assert re.search(r"Breakpoint, PC: %06o " % callback_return, trace)
    assert re.search(r"Breakpoint, PC: %06o " % service_return, trace)
    assert "MEM                                  48 K" in trace
    assert "PURE                              LOADED" in trace
    assert "aaaaaax[BV1641_STAGE_B" in trace
    assert "ZV1641_STAGE_Z" in trace
    assert "HALT instruction" in trace
    for key in ("V1641_LOADER_RETURN_OK", "V1641_ERROR_INJECTED",
                "V1641_ROLLBACK_RETURN", "V1641_RETRY_LOADER_RETURN"):
        assert trace.count(key + "\n") == 1

    for part in ("#define P14_CHILDREN         6U",
                 "pid[i] = p14_spawn(rd, i != 0U);",
                 "denied = p14_spawn(rd, 1U);",
                 "p14_compressed_path[3]",
                 "dsys_read_words(0, &word, 1U)",
                 "p14_data[0] != 012345670123UL",
                 "p14_data[P14_IMAGE_WORDS - 1U] != 076543210765UL",
                 "dsys_wait((unsigned int)pid[i], &status, 0U)",
                 "SYS_WAIT_STATUS_VALUE(status) != P14_STATUS",
                 "(void)p14_char('Z');"):
        assert part in source, "original guest source mismatch: " + part
    p, c = h["dxr_words"](plain), h["dxr_words"](compressed)
    assert p[0] == c[0] and p[2] == c[2]
    assert p[1] >> 18 == c[1] >> 18
    assert (p[1] & 0o300000) == 0o200000
    assert (c[1] & 0o300000) == 0o300000
    assert "F /SYSTEM/COMP " in manifest

    def sample(label):
        words, extents = stage(trace.replace("V1641_", "V1638_"),
                               syms, label)
        slot = 0 if label in ("PINNED_BEFORE_ERROR", "ROLLED_BACK",
                               "RETRY_PINNED") else 1
        assert words[syms["proc_current_slot"]] == slot
        parent = [(a, b, k, pin, owner) for a, b, k, pin, owner
                  in extents if k in (1, 4) and owner == 1]
        assert parent == [(0o130000, 0o140000, 1, 0, 1)]
        return [(a, b, k, pin, owner) for a, b, k, pin, owner
                in extents if k in (1, 4) and 2 <= owner <= 7]

    for label in ("B", "A"):
        owners = sample(label)
        assert len(owners) == 6
        assert {o for a, b, k, p, o in owners} == set(range(2, 8))
        assert all(k == 4 and b-a == 0o7000 and p == 0
                   for a, b, k, p, o in owners)

    before = sample("PINNED_BEFORE_ERROR")
    dest = [(a, b, pin, owner) for a, b, k, pin, owner in before
            if k == 1 and pin == 1 and 2 <= owner <= 7]
    assert len(dest) == 1 and dest[0][1] - dest[0][0] == 0o10000
    slot = dest[0][3]
    assert slot in (3, 4, 5, 6, 7), "callback must use compressed PURE"
    raw = [(a, b, pin) for a, b, k, pin, owner in before
           if k == 4 and owner == slot]
    assert len(raw) == 1 and raw[0][2] == 1
    assert raw[0][1] - raw[0][0] == 0o7000
    assert dest[0][1] <= raw[0][0] or raw[0][1] <= dest[0][0]

    # AC1 actually returned zero from the original bounded FULL loader.
    callback_section = trace.split("V1641_LOADER_RETURN_OK\n", 1)[1]
    before_stage = callback_section.split("V1641_STAGE_PINNED_BEFORE_ERROR\n", 1)[0]
    assert re.search(r"(?m)^1:\s*0+\s*$", before_stage), \
        "the original FULL loader did not succeed before injection"
    injected = trace.split("V1641_END_PINNED_BEFORE_ERROR\n", 1)[1].split(
        "V1641_ERROR_INJECTED\n", 1)[0]
    assert re.search(r"(?m)^1:\s*777777777777\s*$", injected), \
        "simulator did not inject negative callback AC1"
    rolled_return = trace.split("V1641_ROLLBACK_RETURN\n", 1)[1].split(
        "V1641_STAGE_ROLLED_BACK\n", 1)[0]
    assert re.search(r"(?m)^1:\s*777777777774\s*$", rolled_return), \
        "v1391 failed FULL loader did not return MM_ERR_INVAL (-4)"

    after = sample("ROLLED_BACK")
    assert not any(k == 1 and o == slot for a, b, k, pin, o in after), \
        "FULL destination owner leaked after callback failure"
    old_raw = [(a, b, pin) for a, b, k, pin, owner in after
               if k == 4 and owner == slot]
    assert old_raw == [(raw[0][0], raw[0][1], 0)], \
        "original PACKED suffix changed or stayed pinned"
    assert all(pin == 0 for a, b, k, pin, owner in after)

    retry_line = trace.split("V1641_RETRY_LOADER_RETURN\n", 1)[1].split(
        "V1641_STAGE_RETRY_PINNED\n", 1)[0]
    assert re.search(r"(?m)^1:\s*0+\s*$", retry_line), \
        "later original loader did not return success"
    retry = sample("RETRY_PINNED")
    full_retry = [(a, b, pin, owner) for a, b, k, pin, owner in retry
                  if k == 1 and pin == 1 and 2 <= owner <= 7]
    assert len(full_retry) == 1 and full_retry[0][1]-full_retry[0][0] == 0o10000
    retry_owner = full_retry[0][3]
    assert retry_owner in (3, 4, 5, 6, 7)
    assert len([(a, b) for a, b, k, pin, owner in retry
                if k == 4 and pin == 1 and owner == retry_owner]) == 1
    assert not sample("Z"), "child PROCESS or PACKED MM owner after WAITs"
    print("v1641: original compressed FULL callback returned 0 then injected -1")
    print("v1641: slot%o pinned PACKED %06o..%06o and FULL %06o..%06o" %
          (slot, raw[0][0], raw[0][1], dest[0][0], dest[0][1]))
    print("v1641: original v1391 returned -4, source preserved, target freed")
    print("v1641: later original FULL success for slot%o, six WAITs, HALT" %
          retry_owner)
    print("PASS v1641: one-shot simulated loader error is failure-atomic")
    print("v1641: real VFS/device failure is not tested")


def main():
    p = argparse.ArgumentParser()
    for key in ("kcore_map", "mres_map", "mres_dxrcheck", "trace",
                "source", "plain_dxr", "compressed_dxr", "manifest"):
        p.add_argument(key, type=Path)
    args = p.parse_args()
    files = [getattr(args, k) for k in
             ("kcore_map", "mres_map", "mres_dxrcheck", "trace",
              "source", "plain_dxr", "compressed_dxr", "manifest")]
    try:
        data = [(v.read_bytes() if i in (5, 6) else
                 v.read_text(encoding="ascii"))
                for i, v in enumerate(files)]
        audit(*data)
    except (AssertionError, UnicodeError, KeyError, ValueError) as e:
        p.exit(1, "FAIL v1641 simulated FULL loader rollback: %s\n" % e)


if __name__ == "__main__":
    main()
