#!/usr/bin/env python3
"""Original native source mm_unpin -4, safe target disposal, retry and HALT."""

from pathlib import Path
import hashlib
import re
import runpy
import sys


def segment(trace, first, last):
    left = "V1899_%s\n" % first
    right = "V1899_%s\n" % last
    if trace.count(left) != 1 or trace.count(right) != 1:
        raise ValueError("original physical source-unpin boundary missing: " + first)
    return trace.split(left, 1)[1].split(right, 1)[0]


def physical_word(text, address):
    found = re.findall(r"(?m)^%o:\s*([0-7]{12})\s*$" % address, text)
    if len(found) != 1:
        raise ValueError("original physical word missing or repeated: %06o" % address)
    return int(found[0], 8)


def run(kit, build, work):
    audit = runpy.run_path(str(kit / "tests/diagnostics/"
                     "pure-full-restore-v1638/audit-v1638.py"))
    core = audit["symbols"]((build / "kcore.map").read_text(encoding="ascii"))
    trace = (work / "physical.clean").read_text(encoding="ascii")
    expected = dict((key, int(val, 8)) for key, val in re.findall(
        r"(?m)^([a-z0-9_]+)\s+([0-7]+)\s*$",
        (work / "expected-v1899.txt").read_text(encoding="ascii")))
    if hashlib.sha256((build / "kcore.dxr").read_bytes()).hexdigest() != \
            "33bf700218a73fefcb36ebb1f1d835c1817f3a291a642898ccb3cbd5d9039d8b" or \
            hashlib.sha256((build / "pure-mres-v1612.dxr").read_bytes()).hexdigest() != \
            "a0fb25c51cf1c57f4bc70ca1dc83d8b9ea39b1ac3ddb3bba7b9ffcea17e5b3fd":
        raise ValueError("original accepted fixed KCORE/PURE DXR bytes changed")
    guest = (build.parent / "user/init-v1614.c").read_text(encoding="ascii")
    if guest.count("#define P14_CHILDREN         5U") != 1 or \
            "(void)p14_char('H');" in guest:
        raise ValueError("v1899 must use original WAIT/HALT five-child guest")
    stages = [
        "V1845_BOUNDED_FULL_SECONDARY\n", "V1845_STAGE_FULL_PINNED\n",
        "V1845_END_FULL_PINNED\n",
        "V1899_ORIGINAL_SOURCE_UNPIN_CALL\n",
        "V1899_STAGE_SOURCE_UNPIN_CALL\n", "V1899_END_SOURCE_UNPIN_CALL\n",
        "V1899_TEST_ONLY_ZERO_SOURCE_PIN\n",
        "V1899_END_TEST_ONLY_ZERO_SOURCE_PIN\n",
        "V1899_ORIGINAL_NATIVE_SOURCE_UNPIN_REFUSAL\n",
        "V1899_STAGE_SOURCE_REFUSED\n", "V1899_END_SOURCE_REFUSED\n",
        "V1899_ORIGINAL_TARGET_ROLLBACK_FREE_CALL\n",
        "V1899_STAGE_TARGET_FREE_CALL\n", "V1899_END_TARGET_FREE_CALL\n",
        "V1899_ORIGINAL_TARGET_FREE_COMMITTED\n",
        "V1899_STAGE_TARGET_FREED\n", "V1899_END_TARGET_FREED\n",
        "V1899_ORIGINAL_FULL_FAILURE_RETURN\n",
        "V1899_STAGE_FAILED_FULL\n", "V1899_END_FAILED_FULL\n",
        "V1899_ORIGINAL_FIVE_CHILD_WAIT_Z\n",
        "V1899_STAGE_Z\n", "V1899_END_Z\n"]
    if any(trace.count(m) != 1 for m in stages) or \
            [trace.index(m) for m in stages] != sorted(trace.index(m) for m in stages):
        raise ValueError("original physical source failure/retry/HALT stages unordered")
    for marker in ("MEM                                  48 K",
                   "PURE                              LOADED", "DTFS                              LOADED",
                   "aaaaax[B"):
        if marker not in trace:
            raise ValueError("not original 48K five-child FULL pressure workload")
    if "detach dtc3" in trace or "V1845_DTC3_DETACHED" in trace:
        raise ValueError("original child executable backing was detached")
    for field in ("target_unpin", "source_unpin", "source_return",
                  "target_free", "target_return", "service_return"):
        if not re.search(r"Breakpoint, PC: %06o " % expected[field], trace):
            # The target unpin must have executed but need not have
            # a breakpoint: it precedes the observed source call.
            if field != "target_unpin":
                raise ValueError("actual original native source-linked PC missing: " + field)
    pinned_frame, pinned = audit["stage"](
        trace.replace("V1845_", "V1638_"), core, "FULL_PINNED")
    source1 = (0o111200, 0o120000, 4, 1, 3)
    source0 = (0o111200, 0o120000, 4, 0, 3)
    target1 = (0o120000, 0o130000, 1, 1, 3)
    target0 = (0o120000, 0o130000, 1, 0, 3)
    if pinned_frame[core["mm_extent_count"]] != 18 or \
            pinned.count(source1) != 1 or pinned.count(target1) != 1:
        raise ValueError("original physical pinned owner pair not exact")
    first_source = [target0 if x == target1 else x for x in pinned]
    both0 = [source0 if x == source1 else x for x in first_source]
    source_only = [x for x in both0 if x != target0]
    root = pinned_frame[core["vfs_namespace_root"]]
    frame, owners = audit["stage"](
        trace.replace("V1899_", "V1638_"), core, "SOURCE_UNPIN_CALL")
    if owners != first_source or frame[core["mm_extent_count"]] != 18:
        raise ValueError("original source unpin was not after successful target unpin")
    meta = expected["source_meta_address"]
    if physical_word(segment(trace, "ORIGINAL_SOURCE_UNPIN_CALL",
                             "STAGE_SOURCE_UNPIN_CALL"), meta) != \
            expected["source_pin1"]:
        raise ValueError("original source did not have one pin at source unpin call")
    if physical_word(segment(trace, "TEST_ONLY_ZERO_SOURCE_PIN",
                             "END_TEST_ONLY_ZERO_SOURCE_PIN"), meta) != \
            expected["source_pin0"]:
        raise ValueError("external zero-source-pin physical injection missing")
    if physical_word(segment(trace, "ORIGINAL_NATIVE_SOURCE_UNPIN_REFUSAL",
                             "STAGE_SOURCE_REFUSED"), 1) != 0o777777777774:
        raise ValueError("original native source mm_unpin did not genuinely return -4")
    frame, owners = audit["stage"](
        trace.replace("V1899_", "V1638_"), core, "SOURCE_REFUSED")
    if owners != both0 or frame[core["mm_extent_count"]] != 18:
        raise ValueError("original source-unpin refusal changed physical MM owners")
    frame, owners = audit["stage"](
        trace.replace("V1899_", "V1638_"), core, "TARGET_FREE_CALL")
    if owners != both0 or frame[core["mm_extent_count"]] != 18:
        raise ValueError("original failed-source-unpin target rollback not entered safely")
    if physical_word(segment(trace, "ORIGINAL_TARGET_FREE_COMMITTED",
                             "STAGE_TARGET_FREED"), 1) != 0:
        raise ValueError("original target rollback mm_free did not return MM_OK")
    frame, owners = audit["stage"](
        trace.replace("V1899_", "V1638_"), core, "TARGET_FREED")
    if owners != source_only or frame[core["mm_extent_count"]] != 17:
        raise ValueError("original rollback lost RAW source or kept target after success")
    if physical_word(segment(trace, "ORIGINAL_FULL_FAILURE_RETURN",
                             "STAGE_FAILED_FULL"), 1) != 0o777777777774:
        raise ValueError("original FULL did not preserve real source-unpin -4 return")
    if physical_word(segment(trace, "STAGE_FAILED_FULL", "END_FAILED_FULL"),
                     core["proc_table"]) != expected["process_table"]:
        raise ValueError("original process table pointer not stable")
    meta3 = physical_word(segment(trace, "STAGE_FAILED_FULL", "END_FAILED_FULL"),
                          expected["process_table"] + 9)
    vm3 = physical_word(segment(trace, "STAGE_FAILED_FULL", "END_FAILED_FULL"),
                        expected["process_table"] + 10)
    if not (meta3 & (1 << 16)) or (vm3 & 0o777777):
        raise ValueError("original source-unpin error falsely published resident APR")
    frame, owners = audit["stage"](
        trace.replace("V1899_", "V1638_"), core, "FAILED_FULL")
    if owners != source_only or frame[core["mm_extent_count"]] != 17:
        raise ValueError("original FULL return lost sole RAW owner after target free")
    for tag in ("SOURCE_UNPIN_CALL", "SOURCE_REFUSED", "TARGET_FREE_CALL",
                "TARGET_FREED", "FAILED_FULL"):
        fr, _ = audit["stage"](trace.replace("V1899_", "V1638_"), core, tag)
        if fr[core["vfs_namespace_root"]] != root:
            raise ValueError("selected TSFS ROOT changed at original " + tag)
    final, entries = audit["stage"](
        trace.replace("V1899_", "V1638_"), core, "Z")
    if final[core["mm_extent_count"]] != 8 or \
            any(owner == 3 and kind in (1, 4) for x, y, kind, pin, owner in entries):
        raise ValueError("original final child cleanup left slot3 MM owner")
    if final[core["vfs_namespace_root"]] != root:
        raise ValueError("original final TSFS root changed")
    progress = trace.split("V1845_END_A\n", 1)[1].split(
        "V1899_ORIGINAL_FIVE_CHILD_WAIT_Z\n", 1)[0]
    if progress.count("w") != 5 or not progress.endswith("Z") or \
            "HALT instruction, PC: 000000" not in trace:
        raise ValueError("original five child WAIT and real machine HALT did not recover")
    if "!" in trace.split("V1845_END_FULL_PINNED\n", 1)[1].split(
            "V1899_ORIGINAL_FIVE_CHILD_WAIT_Z\n", 1)[0]:
        raise ValueError("original child reports failed syscall or data sentinel")
    print("PASS v1899: genuine original source mm_unpin -4, source zero-pin preserved")
    print("v1899: original target cleanup free succeeded; retained sole RAW source")
    print("v1899: FULL nonresident TRANSITION VM0, five child retry/WAIT/HALT PASS")
    print("NOT PROVEN: naturally occurring PI-atomic source pin loss or foreign owner")


if __name__ == "__main__":
    if len(sys.argv) != 4:
        raise SystemExit("usage: verify-v1899.py kit original-build physical-work")
    try:
        run(*(Path(s) for s in sys.argv[1:]))
    except (ValueError, KeyError, OSError, AssertionError, UnicodeError) as exc:
        raise SystemExit("FAIL v1899 original physical source-unpin refusal: " + str(exc))
