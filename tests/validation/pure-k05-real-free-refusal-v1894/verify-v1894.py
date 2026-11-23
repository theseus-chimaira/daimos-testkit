#!/usr/bin/env python3
"""Audit genuine PDP6 mm_free busy refusal and exact two-owner rollback."""

from pathlib import Path
import hashlib
import re
import runpy
import sys


def words_in_section(trace, first, last):
    a = "V1894_%s\n" % first
    b = "V1894_%s\n" % last
    if trace.count(a) != 1 or trace.count(b) != 1:
        raise ValueError("missing or duplicate physical stage: " + first)
    body = trace.split(a, 1)[1].split(b, 1)[0]
    return dict((int(addr, 8), int(val, 8)) for addr, val in re.findall(
        r"(?m)^([0-7]+):\s*([0-7]{12})\s*$", body))


def one(table, address):
    if address not in table:
        raise ValueError("missing original hardware address %06o" % address)
    return table[address]


def read(kit, build, work):
    stage = runpy.run_path(str(kit / "tests/diagnostics/"
                  "pure-full-restore-v1638/audit-v1638.py"))
    core = stage["symbols"]((build / "kcore.map").read_text(encoding="ascii"))
    trace = (work / "physical.clean").read_text(encoding="ascii")
    expected = dict((k, int(v, 8)) for k, v in re.findall(
        r"(?m)^([a-z0-9_]+)\s+([0-7]+)\s*$",
        (work / "expected-v1894.txt").read_text(encoding="ascii")))
    if hashlib.sha256((build / "kcore.dxr").read_bytes()).hexdigest() != \
            "33bf700218a73fefcb36ebb1f1d835c1817f3a291a642898ccb3cbd5d9039d8b" or \
            hashlib.sha256((build / "pure-mres-v1612.dxr").read_bytes()).hexdigest() != \
            "a0fb25c51cf1c57f4bc70ca1dc83d8b9ea39b1ac3ddb3bba7b9ffcea17e5b3fd":
        raise ValueError("production KCORE/PURE images changed from v1855")
    marks = ["V1845_STAGE_FULL_PINNED\n", "V1845_END_FULL_PINNED\n",
             "V1894_ORIGINAL_SOURCE_FREE_CALL\n",
             "V1894_STAGE_BEFORE_PIN\n", "V1894_END_BEFORE_PIN\n",
             "V1894_TEMPORARY_REAL_PIN\n", "V1894_END_TEMPORARY_REAL_PIN\n",
             "V1894_ACTUAL_MM_FREE_REFUSAL\n",
             "V1894_STAGE_REFUSED\n", "V1894_END_REFUSED\n",
             "V1894_EXTERNAL_PIN_RELEASE\n",
             "V1894_STAGE_TWO_UNPINNED\n", "V1894_END_TWO_UNPINNED\n",
             "V1894_ORIGINAL_ROLLBACK_RETURN\n",
             "V1894_STAGE_ROLLED_BACK\n", "V1894_END_ROLLED_BACK\n",
             "V1894_RECOVERED_CHILDREN_WAIT_Z\n",
             "V1894_STAGE_Z\n", "V1894_END_Z\n"]
    if any(trace.count(x) != 1 for x in marks) or \
            [trace.index(x) for x in marks] != sorted(trace.index(x) for x in marks):
        raise ValueError("physical native MM refusal stage order incorrect")
    if "MEM                                  48 K" not in trace or \
            "PURE                              LOADED" not in trace or \
            "DTFS                              LOADED" not in trace or \
            "aaaaax[B" not in trace:
        raise ValueError("not original source-built 48K five-child FULL")
    if "detach dtc3" in trace or "V1845_DTC3_DETACHED" in trace:
        raise ValueError("original secondary executable backing disappeared")
    for name, field in (("source_call", "ORIGINAL_SOURCE_FREE_CALL"),
                        ("source_return", "ACTUAL_MM_FREE_REFUSAL"),
                        ("service_return", "ORIGINAL_ROLLBACK_RETURN")):
        if not re.search(r"Breakpoint, PC: %06o " % expected[name], trace):
            raise ValueError("original source-linked mm_free PC missing: " + field)
    pinned_block, pinned = stage["stage"](
        trace.replace("V1845_", "V1638_"), core, "FULL_PINNED")
    base = (0o111200, 0o120000, 4, 1, 3)
    dest = (0o120000, 0o130000, 1, 1, 3)
    if pinned.count(base) != 1 or pinned.count(dest) != 1:
        raise ValueError("original FULL pinned source/target pair missing")
    src0 = (base[0], base[1], base[2], 0, base[4])
    dst0 = (dest[0], dest[1], dest[2], 0, dest[4])
    replaced = [src0 if x == base else dst0 if x == dest else x for x in pinned]
    before, both = stage["stage"](
        trace.replace("V1894_", "V1638_"), core, "BEFORE_PIN")
    if both != replaced or before[core["mm_extent_count"]] != 18:
        raise ValueError("original source-free entry did not unpin BOTH owners")
    addr = expected["source_meta_address"]
    if one(words_in_section(trace, "ORIGINAL_SOURCE_FREE_CALL", "STAGE_BEFORE_PIN"),
           addr) != expected["source_meta_pin0"]:
        raise ValueError("original source MM pin not physically zero at free call")
    if one(words_in_section(trace, "TEMPORARY_REAL_PIN", "END_TEMPORARY_REAL_PIN"),
           addr) != expected["source_meta_pin1"]:
        raise ValueError("original source MM physical pin injection missing")
    refused, one_pin = stage["stage"](
        trace.replace("V1894_", "V1638_"), core, "REFUSED")
    if one_pin != [base if x == src0 else x for x in replaced] or \
            refused[core["mm_extent_count"]] != before[core["mm_extent_count"]]:
        raise ValueError("native mm_free BUSY did not preserve both owners/pins")
    if one(words_in_section(trace, "ACTUAL_MM_FREE_REFUSAL", "STAGE_REFUSED"),
           1) != 0o777777777773:
        raise ValueError("original MM did not actually refuse pinned source -5")
    if one(words_in_section(trace, "EXTERNAL_PIN_RELEASE", "STAGE_TWO_UNPINNED"),
           addr) != expected["source_meta_pin0"]:
        raise ValueError("temporary external pin was not physically released")
    two_block, two = stage["stage"](
        trace.replace("V1894_", "V1638_"), core, "TWO_UNPINNED")
    if two != replaced or two_block[core["mm_extent_count"]] != 18:
        raise ValueError("genuinely refused free did not retain exact two unpinned owners")
    returned = words_in_section(trace, "ORIGINAL_ROLLBACK_RETURN", "STAGE_ROLLED_BACK")
    if one(returned, 1) != 0o777777777773:
        raise ValueError("original v1839 rollback failed to return actual MM_BUSY")
    if one(returned, core["proc_table"]) != expected["process_table"]:
        raise ValueError("KCORE process-table pointer changed after refusal")
    v = one(returned, expected["process_table"] + 3 * 3 + 1)
    if v & 0o777777:
        raise ValueError("refused PACKED restore published invalid runnable APR")
    rolled, after_rollback = stage["stage"](
        trace.replace("V1894_", "V1638_"), core, "ROLLED_BACK")
    if after_rollback != [x for x in replaced if x != dst0] or \
            rolled[core["mm_extent_count"]] != 17:
        raise ValueError("original v1839 two-unpinned-owner branch failed target rollback")
    if any(block[core["vfs_namespace_root"]] !=
           pinned_block[core["vfs_namespace_root"]] for block in
           (before, refused, two_block, rolled)):
        raise ValueError("refused source free mutated selected TSFS root")
    final, final_extents = stage["stage"](
        trace.replace("V1894_", "V1638_"), core, "Z")
    if any(owner == 3 and kind in (1, 4)
           for start, end, kind, pin, owner in final_extents):
        raise ValueError("original child final cleanup retained slot3 process")
    progress = trace.split("V1845_END_A\n", 1)[1].split(
        "V1894_RECOVERED_CHILDREN_WAIT_Z\n", 1)[0]
    if progress.count("w") != 5 or not progress.endswith("Z") or \
            "HALT instruction, PC: 000000" not in trace:
        raise ValueError("original five-child EXIT/WAIT/HALT did not recover")
    if final[core["vfs_namespace_root"]] != pinned_block[core["vfs_namespace_root"]]:
        raise ValueError("original terminal cleanup changed TSFS root")
    print("PASS v1894: original actual fixed-KCORE mm_free refused temporary source pin")
    print("v1894: original -5 refusal physically retains both complete target and RAW source")
    print("v1894: released external pin => exact zero-pin pair => safe target rollback")
    print("v1894: original five children recovered, EXIT/WAIT and final HALT PASS")


if __name__ == "__main__":
    if len(sys.argv) != 4:
        raise SystemExit("usage: verify-v1894.py testkit build original-physical-work")
    try:
        read(*(Path(x) for x in sys.argv[1:]))
    except (ValueError, KeyError, OSError, AssertionError, UnicodeError) as exc:
        raise SystemExit("FAIL v1894 real physical MM refusal: " + str(exc))
