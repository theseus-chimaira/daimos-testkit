#!/usr/bin/env python3
"""Physical nine-owner PDP-6 MM oracle for genuine one-time failed rebase.

Reuses the original versioned v1673 physical MM/PROC/SYS_MEMINFO parser.
A failed precommit DROP leaves one resident child, not nine PACKED
children; never weaken the old nine-PACKED v1673 acceptance gate.
"""
import importlib.util
import json
import re
import sys
from pathlib import Path


old = Path(__file__).resolve().parent.parent / "pure-runtime-reclaim-v1673" / "measure-v1673.py"
spec = importlib.util.spec_from_file_location("physical_owner_v1673", old)
P1673 = importlib.util.module_from_spec(spec)
spec.loader.exec_module(P1673)


def run(args):
    if len(args) != 6:
        raise ValueError("usage: measure-v1678.py fixture.map kcore.map "
                         "console.clean 48 report.json")
    fixture, coremap, source, value, target = args[1:]
    core = int(value)
    if core != 48:
        raise ValueError("v1678 physical fault scoped to 48K")
    content = Path(source).read_text(encoding="ascii").replace("\r", "")
    for marker in ("V1673 START CHILDREN", "V1673 BASELINE",
                   "V1673 PRESSURE", "V1673 REAPED",
                   "V1673 TRIGGER RUN 9", "V1673 TRIGGER REFUSED",
                   "V1673 PASS RUN EXIT WAIT", "V1674 PIPE RELEASED"):
        if content.count(marker) != 1:
            raise ValueError("missing/duplicate real guest milestone " + marker)
    if any(s in content for s in ("V1673 RUN FAILURE", "V1673 WAIT FAILURE",
                                  "V1674 PIPE RELEASE FAILURE", "SWAP FAIL",
                                  "HALT instruction", "V1673 BAD INITIAL PROCESS",
                                  "V1673 MEMINFO FAILURE")):
        raise ValueError("real child or MM operation failed")
    if not re.search(r"^MEM\s+48 K\s*$", content, re.M) or \
            not re.search(r"^PURE\s+LOADED\s*$", content, re.M):
        raise ValueError("not a real 48K installed PURE boot")
    address = {name: P1673.lookup(coremap, name) for name in P1673.GLOBALS}
    for name in ("mm_arenas", "mm_extents"):
        address[name] = P1673.lookup(coremap, name)
    events = P1673.observations(content, fixture)
    samples = [P1673.read_event(event, address, core) for event in events]
    a, b, c = samples
    if len(a["process_states"]) != 1 or len(c["process_states"]) != 1 or \
            len(b["process_states"]) != 10 or \
            a["packed_apr_count"] or c["packed_apr_count"] or \
            b["packed_apr_count"] != 8 or b["process_apr_count"] != 2 or \
            a["process_apr_count"] != 1 or c["process_apr_count"] != 1:
        raise ValueError("v1678 requires exactly one unreclaimed RESIDENT "
                         "and eight real PACKED children")
    children = {p["slot"]: p for p in b["process_states"] if p["slot"] > 1}
    if set(children) != set(range(2, 11)):
        raise ValueError("nine real child process owners not observed")
    residents = [p for p in children.values() if p["storage_mode"] == 0]
    if len(residents) != 1 or residents[0]["state"] != 3:
        raise ValueError("the failed rebase did not retain one sleeping "
                         "full RESIDENT child")
    victim = residents[0]
    for slot, p in children.items():
        if p["vm_words"] != (3072 if slot <= 6 else 2048):
            raise ValueError("child logical BRK size changed")
        if p["storage_mode"] == 2 and \
                p["physical"]["words"] != p["vm_words"] - 128:
            raise ValueError("other child RAW skip was not exactly 128")
    # The original *physical* process metadata must have the prior
    # transition bit cleared, not merely a nonzero runnable APR image.
    table_ptr = events[1]["words"][address["proc_table"]]
    meta_at_b = events[1]["words"][table_ptr + 3 * victim["slot"]]
    if meta_at_b & (1 << 16):
        raise ValueError("precommit-rejected original MM owner still "
                         "transition-held at B")
    if b["process_high_slot"] >= b["process_capacity"] or \
            not (b["largest_free_words"] < 2048 <= b["free_words"]):
        raise ValueError("tenth RUN refusal was not physical fragmentation")
    if a["pinned_extents"] != b["pinned_extents"] or \
            a["pinned_extents"] != c["pinned_extents"]:
        raise ValueError("original MM pinned descriptor leak at B or C")
    if a["resident_words"] != b["resident_words"] or \
            a["resident_words"] != c["resident_words"]:
        raise ValueError("permanent KCORE resident words changed")
    if not (b["free_words"] < a["free_words"] and
            c["free_words"] == a["free_words"] and
            c["largest_free_words"] == a["largest_free_words"]):
        raise ValueError("physical MM space not precisely recovered")
    # Unlike stale descriptors beyond count, the live original MM
    # descriptor table must be bit-identical after the final WAIT.
    count = address["mm_extent_count"]
    base = address["mm_extents"]
    words_a, words_c = events[0]["words"], events[2]["words"]
    if words_a[count] != words_c[count] or any(
            words_a[base + i] != words_c[base + i]
            for i in range(2 * words_a[count])):
        raise ValueError("original live physical MM descriptors "
                         "not restored exactly at C")
    reported = {}
    for field in ("TOTAL", "RESIDENT", "PROCESS-WORDS", "PROC-SLOTS"):
        vals = [int(n) for n in re.findall(
            r"^V1673 " + field + r" ([0-9]+)\s*$", content, re.M)]
        if len(vals) != 3:
            raise ValueError("original native MEMINFO missing " + field)
        reported[field] = vals
    for i, item in enumerate(samples):
        if reported["TOTAL"][i] != 49152 or \
                reported["RESIDENT"][i] != item["resident_words"] or \
                reported["PROCESS-WORDS"][i] != item["resident_process_words"] or \
                reported["PROC-SLOTS"][i] != len(item["process_states"]) + 1:
            raise ValueError("original native MEMINFO inconsistent with "
                             "physical resident/packed MM at %d" % i)
    report = dict(core_kwords=48, children_requested=9,
                  native_meminfo=reported, rejected_resident_slot=victim["slot"],
                  baseline=a, pressure=b, reaped=c, samples=samples)
    Path(target).write_text(json.dumps(report, indent=2, sort_keys=True)
                            + "\n", encoding="ascii")
    print("PASS v1678 48K: one original rebase refused, "
          "8 PACKED + 1 resident, free MM %d->%d->%d" %
          (a["free_words"], b["free_words"], c["free_words"]))


if __name__ == "__main__":
    try:
        run(sys.argv)
    except (ValueError, OSError) as exc:
        raise SystemExit("FAIL v1678 physical precommit MM oracle: " + str(exc))
