#!/usr/bin/env python3
"""Original PDP-6 target cleanup free commits but its AC1 reply is lost."""

from pathlib import Path
import hashlib
import re
import runpy
import sys


def span(text, prefix, first, last):
    start = "V%s_%s\n" % (prefix, first)
    end = "V%s_%s\n" % (prefix, last)
    if text.count(start) != 1 or text.count(end) != 1:
        raise ValueError("missing original physical native-free checkpoint: " + first)
    return text.split(start, 1)[1].split(end, 1)[0]


def word(text, address):
    matches = re.findall(r"(?m)^%o:\s*([0-7]{12})\s*$" % address, text)
    if len(matches) != 1:
        raise ValueError("original physical word not unique %06o" % address)
    return int(matches[0], 8)


def read(kit, build, work):
    audit = runpy.run_path(str(kit / "tests/diagnostics/"
                     "pure-full-restore-v1638/audit-v1638.py"))
    core = audit["symbols"]((build / "kcore.map").read_text(encoding="ascii"))
    trace = (work / "physical.clean").read_text(encoding="ascii")
    exp = dict((key, int(val, 8)) for key, val in re.findall(
        r"(?m)^([a-z0-9_]+)\s+([0-7]+)\s*$",
        (work / "expected-v1897.txt").read_text(encoding="ascii")))
    if hashlib.sha256((build / "kcore.dxr").read_bytes()).hexdigest() != \
            "33bf700218a73fefcb36ebb1f1d835c1817f3a291a642898ccb3cbd5d9039d8b" or \
            hashlib.sha256((build / "pure-mres-v1612.dxr").read_bytes()).hexdigest() != \
            "a0fb25c51cf1c57f4bc70ca1dc83d8b9ea39b1ac3ddb3bba7b9ffcea17e5b3fd":
        raise ValueError("not accepted original v1855 physical production KCORE/PURE")
    markers = [
        "V1845_BOUNDED_FULL_SECONDARY\n",
        "V1845_STAGE_FULL_PINNED\n", "V1845_END_FULL_PINNED\n",
        "V1894_ORIGINAL_SOURCE_FREE_CALL\n",
        "V1894_STAGE_BEFORE_PIN\n", "V1894_END_BEFORE_PIN\n",
        "V1894_TEMPORARY_REAL_PIN\n", "V1894_END_TEMPORARY_REAL_PIN\n",
        "V1894_ACTUAL_MM_FREE_REFUSAL\n",
        "V1894_STAGE_REFUSED\n", "V1894_END_REFUSED\n",
        "V1894_EXTERNAL_PIN_RELEASE\n", "V1894_STAGE_TWO_UNPINNED\n",
        "V1894_END_TWO_UNPINNED\n",
        "V1897_ORIGINAL_TARGET_FREE_CALL\n",
        "V1897_STAGE_TARGET_FREE_CALL\n", "V1897_END_TARGET_FREE_CALL\n",
        "V1897_ORIGINAL_SUCCESSFUL_TARGET_FREE_RETURN\n",
        "V1897_STAGE_TARGET_FREED\n", "V1897_END_TARGET_FREED\n",
        "V1897_FORGED_FAILED_TARGET_FREE_REPLY\n",
        "V1897_END_FORGED_FAILED_TARGET_FREE_REPLY\n",
        "V1897_ORIGINAL_FAILED_FULL_RETURN\n",
        "V1897_STAGE_FAILED_FULL\n", "V1897_END_FAILED_FULL\n",
        "V1897_ORIGINAL_CHILDREN_WAIT_Z\n",
        "V1897_STAGE_Z\n", "V1897_END_Z\n"]
    if any(trace.count(x) != 1 for x in markers) or \
            [trace.index(x) for x in markers] != sorted(trace.index(x) for x in markers):
        raise ValueError("original source/target free and child HALT stages unordered")
    for banner in ("MEM                                  48 K",
                   "PURE                              LOADED",
                   "DTFS                              LOADED", "aaaaax[B"):
        if banner not in trace:
            raise ValueError("not original 48K five-child full PURE pressure fixture")
    if "detach dtc3" in trace or "V1845_DTC3_DETACHED" in trace:
        raise ValueError("target cleanup reply lost due to source media detach")
    for key in ("source_call", "source_return", "target_call",
                "target_return", "service_return"):
        if not re.search(r"Breakpoint, PC: %06o " % exp[key], trace):
            raise ValueError("actual original source-linked PC missing: " + key)

    first, pinned = audit["stage"](
        trace.replace("V1845_", "V1638_"), core, "FULL_PINNED")
    source1 = (0o111200, 0o120000, 4, 1, 3)
    source0 = (0o111200, 0o120000, 4, 0, 3)
    target1 = (0o120000, 0o130000, 1, 1, 3)
    target0 = (0o120000, 0o130000, 1, 0, 3)
    if pinned.count(source1) != 1 or pinned.count(target1) != 1 or \
            first[core["mm_extent_count"]] != 18:
        raise ValueError("original FULL pinned authoritative pair not found")
    pair = [source0 if e == source1 else target0 if e == target1 else e
            for e in pinned]
    source_held = [source1 if e == source0 else e for e in pair]
    source_only = [e for e in pair if e != target0]

    before, at_source = audit["stage"](
        trace.replace("V1894_", "V1638_"), core, "BEFORE_PIN")
    if at_source != pair or before[core["mm_extent_count"]] != 18:
        raise ValueError("original source free not reached with two unpinned owners")
    addr = exp["source_meta_address"]
    if word(span(trace, "1894", "TEMPORARY_REAL_PIN", "END_TEMPORARY_REAL_PIN"),
            addr) != exp["source_meta_pin1"]:
        raise ValueError("test-only source free refusal pin was not injected")
    if word(span(trace, "1894", "ACTUAL_MM_FREE_REFUSAL", "STAGE_REFUSED"),
            1) != 0o777777777773:
        raise ValueError("original PACKED source free did not genuinely return -5")
    refused, held = audit["stage"](
        trace.replace("V1894_", "V1638_"), core, "REFUSED")
    if held != source_held or refused[core["mm_extent_count"]] != 18:
        raise ValueError("original source free refusal lost source or target owner")
    if word(span(trace, "1894", "EXTERNAL_PIN_RELEASE", "STAGE_TWO_UNPINNED"),
            addr) != exp["source_meta_pin0"]:
        raise ValueError("test-only source pin not released for exact pair scan")
    released, both0 = audit["stage"](
        trace.replace("V1894_", "V1638_"), core, "TWO_UNPINNED")
    if both0 != pair:
        raise ValueError("original exact zero-pin owner pair not restored")
    at_call, before_target = audit["stage"](
        trace.replace("V1897_", "V1638_"), core, "TARGET_FREE_CALL")
    if before_target != pair or at_call[core["mm_extent_count"]] != 18:
        raise ValueError("original target cleanup call did not see exact two owners")
    if word(span(trace, "1897", "ORIGINAL_TARGET_FREE_CALL", "STAGE_TARGET_FREE_CALL"),
            exp["target_meta_address"]) != 0o000001000003:
        raise ValueError("original target was not physical pin0 at free entry")
    original_ac1 = word(span(trace, "1897", "ORIGINAL_SUCCESSFUL_TARGET_FREE_RETURN",
                             "STAGE_TARGET_FREED"), 1)
    if original_ac1 != 0:
        raise ValueError("original native target cleanup free did not return MM_OK")
    freed, after_target = audit["stage"](
        trace.replace("V1897_", "V1638_"), core, "TARGET_FREED")
    if after_target != source_only or freed[core["mm_extent_count"]] != 17:
        raise ValueError("original native target cleanup did not physically delete target")
    if word(span(trace, "1897", "FORGED_FAILED_TARGET_FREE_REPLY",
                 "END_FORGED_FAILED_TARGET_FREE_REPLY"), 1) != 0o777777777773:
        raise ValueError("target cleanup free success reply not replaced by test-only -5")

    returned = span(trace, "1897", "ORIGINAL_FAILED_FULL_RETURN", "STAGE_FAILED_FULL")
    if word(returned, 1) != 0o777777777773:
        raise ValueError("original failed target-free reply did not report BUSY")
    if word(returned, core["proc_table"]) != exp["process_table"]:
        raise ValueError("original proc_table pointer changed")
    slot3 = word(returned, exp["process_table"] + 9)
    vm3 = word(returned, exp["process_table"] + 10)
    if not (slot3 & (1 << 16)) or (vm3 & 0o777777):
        raise ValueError("original falsely successful rollback published invalid slot3 APR")
    after, still_source = audit["stage"](
        trace.replace("V1897_", "V1638_"), core, "FAILED_FULL")
    if still_source != source_only or after[core["mm_extent_count"]] != 17:
        raise ValueError("original failed cleanup reply lost authoritative RAW source")
    root = first[core["vfs_namespace_root"]]
    if any(x[core["vfs_namespace_root"]] != root for x in
           (before, refused, released, at_call, freed, after)):
        raise ValueError("source or target native free altered selected ROOT")
    final, terminal = audit["stage"](
        trace.replace("V1897_", "V1638_"), core, "Z")
    if any(kind in (1, 4) and owner == 3 for a, b, kind, pins, owner in terminal) or \
            final[core["mm_extent_count"]] != 8:
        raise ValueError("original terminal WAIT left stale slot3 PACKED/PROCESS")
    if final[core["vfs_namespace_root"]] != root:
        raise ValueError("original last child cleanup altered selected ROOT")
    progress = trace.split("V1845_END_A\n", 1)[1].split(
        "V1897_ORIGINAL_CHILDREN_WAIT_Z\n", 1)[0]
    if progress.count("w") != 5 or not progress.endswith("Z") or \
            "HALT instruction, PC: 000000" not in trace:
        raise ValueError("original five child EXIT/WAIT and parent HALT did not recover")
    if "!" in trace.split("V1845_END_FULL_PINNED\n", 1)[1].split(
            "V1897_ORIGINAL_CHILDREN_WAIT_Z\n", 1)[0]:
        raise ValueError("original user reported a failed syscall or sentinel")
    print("PASS v1897: original cleanup mm_free(PROCESS) physically deleted target")
    print("v1897: ONLY post-commit AC1 success reply forged to -5; RAW source retained")
    print("v1897: original FULL remained nonresident, then original child safely retried")
    print("v1897: five original child EXIT/WAIT, final owner cleanup and HALT PASS")


if __name__ == "__main__":
    if len(sys.argv) != 4:
        raise SystemExit("usage: verify-v1897.py testkit original-build physical-work")
    try:
        read(*(Path(s) for s in sys.argv[1:]))
    except (ValueError, KeyError, OSError, AssertionError, UnicodeError) as exc:
        raise SystemExit("FAIL v1897 original target cleanup lost reply: " + str(exc))
