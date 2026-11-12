#!/usr/bin/env python3
"""Strict physical v1509: real independent spinner scheduling under fault.

The inherited v1508 validator independently verifies DISK ownership,
rollback, retry frequency and pending TERM. This adds the original
v1150 count of real PID5 SLEEP entries and linked slot-05 liveness.
"""

from pathlib import Path
import re
import runpy
import sys
import tempfile


HERE = Path(__file__).resolve().parent
V1508 = runpy.run_path(str(HERE / "daimos-backstore-persistent-verify-v1508.py"))


def process_samples(text):
    states = {}
    for line in text.splitlines():
        if not line.startswith("[v1332] process-table sample="):
            continue
        number = re.search(r"\bsample=(\d+)\b", line)
        slot = re.search(r"\bslot05=([A-Z]+)/([DR]):", line)
        if number is None or slot is None:
            raise AssertionError("missing mapped PID5 process-table state")
        index = int(number.group(1))
        if index in states:
            raise AssertionError("duplicate process-table snapshot")
        states[index] = slot.group(1)
    return states


def verify(samples, console, table):
    V1508["verify"](samples, console)
    active = [sample for sample in samples if sample.get("fault") == 1]
    if active[0]["slot"] == 5:
        raise AssertionError("spinner is the failed DISK owner")
    states = process_samples(table)
    last = None
    for sample in active:
        if "spinner" not in sample or "sample" not in sample:
            raise AssertionError("missing actual PID5 progress witness")
        index = sample["sample"]
        if states.get(index) not in ("SLEEP", "RUN"):
            raise AssertionError("independent PID5 is not live")
        count = sample["spinner"]
        if count < 5 or count >= 0o100000:
            raise AssertionError("invalid physical spinner sleep count")
        if last is not None and count <= last:
            raise AssertionError("PID5 did not run between fault-on samples")
        last = count
    if active[-1]["spinner"] - active[0]["spinner"] < 2:
        raise AssertionError("no sustained independent scheduled progress")
    print("PASS v1509: live independent PID5 SLEEP entries %d..%d" %
          (active[0]["spinner"], active[-1]["spinner"]))
    print("PASS v1509: PID5 remains real RUN/SLEEP during each fault sample")
    print("PASS v1509: independent scheduler progress with held DISK/TERM")


def self_test():
    initial = {
        "fault": 1, "slot": 8, "first": 0o2350, "blocks": 0o330,
        "repairs": 0, "owner_term": 0, "private_close": 0,
        "finish": 0, "zombie": 0, "record_count": 1,
        "record": (0o2350 << 18) | 0o330,
        "meta": 0o400000, "vm": 0o330 << 18,
        "sched": 2 << 33, "retry": 1 << 32,
        "fdctl": 0o4 << 18, "cursor": 0o410,
        "swap_blocks": 0o1000, "backstore_blocks": 0o1000,
        "failed_service": 1,
    }
    good = []
    for index in range(5):
        entry = dict(initial)
        entry.update({"sample": index + 3, "timer": index * 0o100,
                      "refused": index + 1,
                      "record_count": index + 1,
                      "failed_service": index + 1,
                      "spinner": index + 12})
        good.append(entry)
    table = "\n".join(
        "[v1332] process-table sample=%d slot05=SLEEP/R:064000:400401" %
        entry["sample"] for entry in good)
    with tempfile.NamedTemporaryFile(mode="w", delete=True) as log:
        verify(good, log.name, table)
        mutants = []
        for label, func in (
            ("frozen", lambda s: s.update(spinner=good[1]["spinner"])),
            ("regressed", lambda s: s.update(spinner=1)),
            ("missing", lambda s: s.pop("spinner")),
            ("missing-index", lambda s: s.pop("sample")),
            ("owner-corrupt", lambda s: s.update(record=0)),
            ("false-ready", lambda s: s.update(cursor=0o1010)),
        ):
            copy = [dict(s) for s in good]
            func(copy[2])
            mutants.append((label, copy, table))
        mutants += [
            ("freed-PID5", good, table.replace("slot05=SLEEP/",
                                           "slot05=FREE/", 1)),
            ("missing-PID5", good, table.replace("slot05=SLEEP/",
                                              "slot06=SLEEP/", 1)),
            ("duplicate-table", good, table + "\n" + table.splitlines()[0]),
        ]
        for label, records, mapping in mutants:
            try:
                verify(records, log.name, mapping)
            except AssertionError:
                continue
            raise AssertionError("v1509 accepted invalid evidence: " + label)
        print("PASS v1509: nine strict negative evidence mutations rejected")


def main():
    if sys.argv[1:] == ["--self-test"]:
        self_test()
        return
    if len(sys.argv) != 3:
        raise SystemExit("usage: v1509.py SAMPLER_LOG GUEST_CONSOLE")
    sampler, console = (Path(path) for path in sys.argv[1:])
    verify(V1508["load"](sampler), console, sampler.read_text(errors="replace"))


if __name__ == "__main__":
    main()
