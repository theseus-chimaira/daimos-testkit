#!/usr/bin/env python3
"""Verify original real PDP6 source-free commit + externally lost reply."""

from pathlib import Path
import hashlib
import re
import runpy
import sys


def span(trace, first, last):
    a = "V1893_%s\n" % first
    b = "V1893_%s\n" % last
    if trace.count(a) != 1 or trace.count(b) != 1:
        raise ValueError("original physical free/reply stage not unique: " + first)
    return trace.split(a, 1)[1].split(b, 1)[0]


def word(trace, address):
    values = re.findall(r"(?m)^%o:\s*([0-7]{12})\s*$" % address, trace)
    if len(values) != 1:
        raise ValueError("physical source-linked word not unique: %06o" % address)
    return int(values[0], 8)


def read(kit, build, work):
    stage_mod = runpy.run_path(str(kit / "tests/diagnostics/"
                     "pure-full-restore-v1638/audit-v1638.py"))
    core = stage_mod["symbols"]((build / "kcore.map").read_text(encoding="ascii"))
    trace = (work / "physical.clean").read_text(encoding="ascii")
    inputs = dict((name, int(value, 8)) for name, value in re.findall(
        r"(?m)^([a-z0-9_]+)\s+([0-7]+)\s*$",
        (work / "expected-v1893.txt").read_text(encoding="ascii")))
    if hashlib.sha256((build / "kcore.dxr").read_bytes()).hexdigest() != \
            "33bf700218a73fefcb36ebb1f1d835c1817f3a291a642898ccb3cbd5d9039d8b":
        raise ValueError("not accepted original KCORE")
    if hashlib.sha256((build / "pure-mres-v1612.dxr").read_bytes()).hexdigest() != \
            "a0fb25c51cf1c57f4bc70ca1dc83d8b9ea39b1ac3ddb3bba7b9ffcea17e5b3fd":
        raise ValueError("not accepted original opt-in MRES")
    marks = ["V1845_BOUNDED_FULL_SECONDARY\n",
             "V1845_STAGE_FULL_PINNED\n", "V1845_END_FULL_PINNED\n",
             "V1893_REAL_SOURCE_FREE_RETURN\n",
             "V1893_STAGE_SOURCE_FREED\n", "V1893_END_SOURCE_FREED\n",
             "V1893_FORGED_FAILED_REPLY\n", "V1893_END_FORGED_REPLY\n",
             "V1893_ORIGINAL_RECOVERED_FULL_RETURN\n",
             "V1893_STAGE_RESTORED\n", "V1893_END_RESTORED\n",
             "V1893_NORMAL_CHILDREN_WAIT_Z\n",
             "V1893_STAGE_Z\n", "V1893_END_Z\n"]
    if any(trace.count(x) != 1 for x in marks) or \
            [trace.index(x) for x in marks] != sorted(trace.index(x) for x in marks):
        raise ValueError("source-free/return/normal-WAIT original stages not ordered")
    if "MEM                                  48 K" not in trace or \
            "PURE                              LOADED" not in trace or \
            "DTFS                              LOADED" not in trace or \
            "aaaaax[B" not in trace:
        raise ValueError("not original source-built 48K five-child PURE pressure")
    if "detach dtc3" in trace or "V1845_DTC3_DETACHED" in trace:
        raise ValueError("physical source media vanished in free-reply test")
    for key, event in (("mm_free_return", "REAL_SOURCE_FREE_RETURN"),
                       ("service_return", "ORIGINAL_RECOVERED_FULL_RETURN")):
        if not re.search(r"Breakpoint, PC: %06o " % inputs[key], trace):
            raise ValueError("real original source-linked return PC absent: " + key)
    if word(span(trace, "REAL_SOURCE_FREE_RETURN", "STAGE_SOURCE_FREED"), 1) != 0:
        raise ValueError("original physical mm_free did not genuinely succeed")
    before, prior = stage_mod["stage"](
        trace.replace("V1845_", "V1638_"), core, "FULL_PINNED")
    after_free, freed = stage_mod["stage"](
        trace.replace("V1893_", "V1638_"), core, "SOURCE_FREED")
    expected_source = (0o111200, 0o120000, 4, 1, 3)
    before_target = (0o120000, 0o130000, 1, 1, 3)
    after_target = (0o120000, 0o130000, 1, 0, 3)
    if prior.count(expected_source) != 1 or prior.count(before_target) != 1:
        raise ValueError("original FULL never held two singly pinned MM owners")
    if any(e[4] == 3 and e[2] in (1, 4) for e in freed if e != after_target) or \
            freed.count(after_target) != 1:
        raise ValueError("real mm_free did not retain sole complete PROCESS owner")
    expected_after = [after_target if x == before_target else x for x in prior
                      if x != expected_source]
    if freed != expected_after or \
            after_free[core["mm_extent_count"]] != before[core["mm_extent_count"]] - 1:
        raise ValueError("real source-free changed unrelated physical MM owners")
    if after_free[core["vfs_namespace_root"]] != before[core["vfs_namespace_root"]]:
        raise ValueError("source-free changed selected TSFS root")
    if word(span(trace, "FORGED_FAILED_REPLY", "END_FORGED_REPLY"), 1) != \
            0o777777777773:
        raise ValueError("source-free AC1 did not carry injected MM_ERR_BUSY")
    recovered = span(trace, "ORIGINAL_RECOVERED_FULL_RETURN", "STAGE_RESTORED")
    if word(recovered, 1) != 0:
        raise ValueError("original v1839 falsely refused successfully freed source")
    if word(recovered, core["proc_table"]) != inputs["original_proc_table"]:
        raise ValueError("physical KCORE proc_table pointer changed")
    slot3_meta = word(recovered, inputs["original_proc_table"] + 3 * 3)
    slot3_vm = word(recovered, inputs["original_proc_table"] + 3 * 3 + 1)
    if slot3_meta & (1 << 16) or (slot3_vm & 0o777777) != 0o120000:
        raise ValueError("physically recovered slot3 not RESIDENT or still TRANSITION")
    restored, published = stage_mod["stage"](
        trace.replace("V1893_", "V1638_"), core, "RESTORED")
    if published != freed or restored[core["vfs_namespace_root"]] != \
            before[core["vfs_namespace_root"]]:
        raise ValueError("source-free reply reconciliation altered original MM/ROOT")
    final, final_extents = stage_mod["stage"](
        trace.replace("V1893_", "V1638_"), core, "Z")
    if any(owner == 3 and kind in (1, 4)
           for a, b, kind, pin, owner in final_extents):
        raise ValueError("original normal WAIT did not free restored slot3 APR")
    # The first genuine child writes 'w' BEFORE the original slot3
    # FULL breakpoint. The four remaining child exits follow the
    # source-free reconciliation, so the physical SIMH snapshot text
    # legitimately interrupts the five output characters. Count
    # only original guest output after stage A and before terminal Z;
    # all physical monitor echo markers use uppercase identifiers.
    progress = trace.split("V1845_END_A\n", 1)[1].split(
        "V1893_NORMAL_CHILDREN_WAIT_Z\n", 1)[0]
    if progress.count("w") != 5 or not progress.endswith("Z") or \
            "HALT instruction, PC: 000000" not in trace:
        raise ValueError("original all-child PIPE/EXIT/WAIT and HALT not completed")
    if "!" in trace.split("V1845_END_FULL_PINNED", 1)[1].split(
            "V1893_NORMAL_CHILDREN_WAIT_Z", 1)[0]:
        raise ValueError("original guest reported a failed syscall/assertion")
    if final[core["vfs_namespace_root"]] != before[core["vfs_namespace_root"]]:
        raise ValueError("original final guest changed selected TSFS root")
    print("PASS v1893: real original mm_free committed PACKED source deletion")
    print("v1893: test-only lost -5 reply physically injected into AC1")
    print("v1893: original v1839 exact-sole-target reconciliation published RESIDENT")
    print("v1893: original five children EXIT/WAIT, owner cleanup, final HALT PASS")


if __name__ == "__main__":
    if len(sys.argv) != 4:
        raise SystemExit("usage: verify-v1893.py testkit build physical-evidence")
    try:
        read(*(Path(x) for x in sys.argv[1:]))
    except (ValueError, KeyError, OSError, AssertionError) as exc:
        raise SystemExit("FAIL v1893 physical lost-successful-free reply: " + str(exc))
