#!/usr/bin/env python3
"""Audit two actual original PDP6 MM free -5 returns and quarantine."""

from pathlib import Path
import hashlib
import re
import runpy
import sys


def section(trace, prefix, begin, end):
    a = "V%s_%s\n" % (prefix, begin)
    b = "V%s_%s\n" % (prefix, end)
    if trace.count(a) != 1 or trace.count(b) != 1:
        raise ValueError("missing original source-linked checkpoint " + begin)
    return trace.split(a, 1)[1].split(b, 1)[0]


def word(block, address):
    found = re.findall(r"(?m)^%o:\s*([0-7]{12})\s*$" % address, block)
    if len(found) != 1:
        raise ValueError("original physical word not unique at %06o" % address)
    return int(found[0], 8)


def read(kit, build, work):
    audit = runpy.run_path(str(kit / "tests/diagnostics/"
                          "pure-full-restore-v1638/audit-v1638.py"))
    core = audit["symbols"]((build / "kcore.map").read_text(encoding="ascii"))
    exp = dict((name, int(val, 8)) for name, val in re.findall(
        r"(?m)^([a-z0-9_]+)\s+([0-7]+)\s*$",
        (work / "expected-v1896.txt").read_text(encoding="ascii")))
    trace = (work / "physical.clean").read_text(encoding="ascii")
    if hashlib.sha256((build / "kcore.dxr").read_bytes()).hexdigest() != \
            "33bf700218a73fefcb36ebb1f1d835c1817f3a291a642898ccb3cbd5d9039d8b" or \
            hashlib.sha256((build / "pure-mres-v1612.dxr").read_bytes()).hexdigest() != \
            "a0fb25c51cf1c57f4bc70ca1dc83d8b9ea39b1ac3ddb3bba7b9ffcea17e5b3fd":
        raise ValueError("original v1855 KCORE/PURE binary hashes differ")
    guest = (build.parent / "user/init-v1614.c").read_text(encoding="ascii")
    for token in ("(void)p14_char('H');", "(void)p14_char('B');",
                  "#define P14_CHILDREN         5U"):
        if guest.count(token) != 1:
            raise ValueError("source-built v1892 resident parent fixture changed")
    if guest.index("(void)p14_char('L');") >= guest.index(
            "(void)p14_char('H');"):
        raise ValueError("parent HB not after original five-child pressure")
    markers = [
        "V1845_STAGE_FULL_PINNED\n", "V1845_END_FULL_PINNED\n",
        "V1894_ORIGINAL_SOURCE_FREE_CALL\n",
        "V1894_STAGE_BEFORE_PIN\n", "V1894_END_BEFORE_PIN\n",
        "V1894_TEMPORARY_REAL_PIN\n", "V1894_END_TEMPORARY_REAL_PIN\n",
        "V1894_ACTUAL_MM_FREE_REFUSAL\n",
        "V1894_STAGE_REFUSED\n", "V1894_END_REFUSED\n",
        "V1894_EXTERNAL_PIN_RELEASE\n", "V1894_END_TWO_UNPINNED\n",
        "V1896_ORIGINAL_TARGET_FREE_CALL\n",
        "V1896_STAGE_TARGET_FREE_CALL\n", "V1896_END_TARGET_FREE_CALL\n",
        "V1896_EXTERNAL_TARGET_PIN_PERSISTENT\n",
        "V1896_END_TARGET_PIN_PERSISTENT\n",
        "V1896_ACTUAL_NATIVE_TARGET_FREE_REFUSAL\n",
        "V1896_STAGE_TARGET_REFUSED\n", "V1896_END_TARGET_REFUSED\n",
        "V1896_ORIGINAL_FULL_FAILED_CLEANUP_RETURN\n",
        "V1896_STAGE_QUARANTINED\n", "V1896_END_QUARANTINED\n",
        "V1896_ACTUAL_RESIDENT_HEARTBEAT_1\n",
        "V1896_STAGE_HEARTBEAT_1\n", "V1896_END_HEARTBEAT_1\n",
        "V1896_ACTUAL_RESIDENT_HEARTBEAT_2\n",
        "V1896_STAGE_HEARTBEAT_2\n", "V1896_END_HEARTBEAT_2\n"]
    if any(trace.count(x) != 1 for x in markers) or \
            [trace.index(x) for x in markers] != sorted(trace.index(x) for x in markers):
        raise ValueError("native source/rollback/parent checkpoint ordering invalid")
    for symbol in ("MEM                                  48 K",
                   "PURE                              LOADED",
                   "DTFS                              LOADED", "aaaaax[B"):
        if symbol not in trace:
            raise ValueError("not original 48K PDP6 five-child PURE pressure")
    if "detach dtc3" in trace or "V1845_DTC3_DETACHED" in trace:
        raise ValueError("original DTC3 backing unexpectedly detached")
    for key in ("source_call", "source_return", "target_call",
                "target_return", "service_return"):
        if not re.search(r"Breakpoint, PC: %06o " % exp[key], trace):
            raise ValueError("actual original native source-linked PC missing: " + key)

    full, original = audit["stage"](trace.replace("V1845_", "V1638_"),
                                    core, "FULL_PINNED")
    source1 = (0o111200, 0o120000, 4, 1, 3)
    source0 = (0o111200, 0o120000, 4, 0, 3)
    target1 = (0o120000, 0o130000, 1, 1, 3)
    target0 = (0o120000, 0o130000, 1, 0, 3)
    if full[core["mm_extent_count"]] != 18 or \
            original.count(source1) != 1 or original.count(target1) != 1:
        raise ValueError("original FULL never owned separate singly pinned extents")
    both0 = [source0 if e == source1 else target0 if e == target1 else e
             for e in original]
    source_held = [source1 if e == source0 else e for e in both0]
    target_held = [target1 if e == target0 else e for e in both0]

    before, free_pair = audit["stage"](
        trace.replace("V1894_", "V1638_"), core, "BEFORE_PIN")
    if free_pair != both0:
        raise ValueError("original source-free call did not start with both pin0")
    source = exp["source_meta_address"]
    target = exp["target_meta_address"]
    if word(section(trace, "1894", "ORIGINAL_SOURCE_FREE_CALL", "STAGE_BEFORE_PIN"),
            source) != exp["source_meta_pin0"]:
        raise ValueError("source meta was pinned before original source-free call")
    if word(section(trace, "1894", "TEMPORARY_REAL_PIN", "END_TEMPORARY_REAL_PIN"),
            source) != exp["source_meta_pin1"]:
        raise ValueError("source-pin fault was not actually injected")
    first_result = section(trace, "1894", "ACTUAL_MM_FREE_REFUSAL", "STAGE_REFUSED")
    if word(first_result, 1) != 0o777777777773:
        raise ValueError("original source mm_free did not genuinely refuse -5")
    source_result, still_both = audit["stage"](
        trace.replace("V1894_", "V1638_"), core, "REFUSED")
    if still_both != source_held or source_result[core["mm_extent_count"]] != 18:
        raise ValueError("original source mm_free lost authoritative PACKED or target")
    if word(section(trace, "1894", "EXTERNAL_PIN_RELEASE", "STAGE_TWO_UNPINNED"),
            source) != exp["source_meta_pin0"]:
        raise ValueError("source pin was not released for checked rollback")
    released, two_unpinned = audit["stage"](
        trace.replace("V1894_", "V1638_"), core, "TWO_UNPINNED")
    if two_unpinned != both0:
        raise ValueError("exact-zero-pin pair missing before target rollback")

    at_target, before_target = audit["stage"](
        trace.replace("V1896_", "V1638_"), core, "TARGET_FREE_CALL")
    if before_target != both0 or at_target[core["mm_extent_count"]] != 18:
        raise ValueError("original cleanup not reached with exact unpinned owner pair")
    if word(section(trace, "1896", "ORIGINAL_TARGET_FREE_CALL", "STAGE_TARGET_FREE_CALL"),
            target) != exp["target_meta_pin0"]:
        raise ValueError("original target was already pinned before cleanup free")
    if word(section(trace, "1896", "EXTERNAL_TARGET_PIN_PERSISTENT",
                    "END_TARGET_PIN_PERSISTENT"), target) != exp["target_meta_pin1"]:
        raise ValueError("target MM external persistent pin injection missing")
    if word(section(trace, "1896", "ACTUAL_NATIVE_TARGET_FREE_REFUSAL",
                    "STAGE_TARGET_REFUSED"), 1) != 0o777777777773:
        raise ValueError("original native MM target free did not genuinely refuse -5")
    refused, post_target = audit["stage"](
        trace.replace("V1896_", "V1638_"), core, "TARGET_REFUSED")
    if post_target != target_held or refused[core["mm_extent_count"]] != 18:
        raise ValueError("original target cleanup free changed protected MM owners")
    root = full[core["vfs_namespace_root"]]
    for frame in (before, source_result, released, at_target, refused):
        if frame[core["vfs_namespace_root"]] != root:
            raise ValueError("original source/target free mutated selected TSFS root")

    prior_clock = None
    for tag in ("QUARANTINED", "HEARTBEAT_1", "HEARTBEAT_2"):
        frame, extents = audit["stage"](
            trace.replace("V1896_", "V1638_"), core, tag)
        block = section(trace, "1896", "STAGE_" + tag, "END_" + tag)
        if extents != target_held or frame[core["mm_extent_count"]] != 18:
            raise ValueError("failed native target cleanup lost MM owners: " + tag)
        if frame[core["vfs_namespace_root"]] != root:
            raise ValueError("selected TSFS root modified during failed target cleanup")
        if word(block, core["proc_table"]) != exp["process_table"]:
            raise ValueError("original process table pointer changed after failure")
        slot3 = word(block, exp["process_table"] + 9)
        vm3 = word(block, exp["process_table"] + 10)
        if not (slot3 & (1 << 16)) or (vm3 & 0o777777):
            raise ValueError("failed target rollback cleared TRANSITION or published APR")
        if tag == "QUARANTINED":
            if word(section(trace, "1896", "ORIGINAL_FULL_FAILED_CLEANUP_RETURN",
                            "STAGE_QUARANTINED"), 1) != 0o777777777773:
                raise ValueError("failed target cleanup lost original MM_ERR_BUSY reply")
        else:
            if frame[core["proc_current_slot"]] != 1:
                raise ValueError("postfailure user HB not dispatched as original parent")
            parent_meta = word(block, exp["process_table"] + 3)
            parent_vm = word(block, exp["process_table"] + 4)
            parent_sched = word(block, exp["process_table"] + 5)
            if parent_meta & (1 << 16) or \
                    (parent_vm & 0o777777) != 0o130000 or \
                    (parent_sched >> 33 & 7) != 2 or \
                    (0o130000, 0o140000, 1, 0, 1) not in extents:
                raise ValueError("unrelated parent no longer resident/SRUN after cleanup failure")
        clock = word(block, core["proc_timer_clock"])
        # The first HB may share the original PCLK interval of the
        # failure; demand a REAL advance only between two new HBs.
        if tag == "HEARTBEAT_2" and (prior_clock is None or clock <= prior_clock):
            raise ValueError("original PCLK failed to advance between new user heartbeats")
        if tag != "QUARANTINED":
            prior_clock = clock

    for event, left in (("ACTUAL_RESIDENT_HEARTBEAT_1", "V1896_END_QUARANTINED\n"),
                        ("ACTUAL_RESIDENT_HEARTBEAT_2", "V1896_END_HEARTBEAT_1\n")):
        interval = trace.split(left, 1)[1].split("V1896_" + event + "\n", 1)[0]
        if not re.search(r"HB\s*$", interval):
            raise ValueError("original user did not emit both independent postfailure HB")
    print("PASS v1896: real original source mm_free -5, exact zero-pin owner pair restored")
    print("v1896: original cleanup mm_free(PROCESS) genuinely returned MM_ERR_BUSY=-5")
    print("v1896: all 18 MM owners conserved; source pin0, target pin1; TRANSITION VM0")
    print("v1896: original parent two user HBs, real original PCLK advancement")
    print("NOT PROVEN: quarantined target terminal cleanup, PIN release, child WAIT/HALT")


if __name__ == "__main__":
    if len(sys.argv) != 4:
        raise SystemExit("usage: verify-v1896.py kit original-build physical-work")
    try:
        read(*(Path(s) for s in sys.argv[1:]))
    except (ValueError, KeyError, OSError, AssertionError, UnicodeError) as exc:
        raise SystemExit("FAIL v1896 original target cleanup refusal: " + str(exc))
