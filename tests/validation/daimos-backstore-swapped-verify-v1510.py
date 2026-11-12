#!/usr/bin/env python3
"""Verify real physical slot 011 checked restore AND subsequent dispatch.

Inherit all v1508 permanent-owner invariants and v1509 PID5 fairness
requirements. Independent counters are incremented at committed
slot-011 swap service returns and at its genuine user SLEEP syscall.
"""

from pathlib import Path
import re
import runpy
import sys
import tempfile


HERE = Path(__file__).resolve().parent
V1508 = runpy.run_path(str(HERE / "daimos-backstore-persistent-verify-v1508.py"))
V1509 = runpy.run_path(str(HERE / "daimos-backstore-bystander-verify-v1509.py"))


def slot11_states(text):
    mapping = {}
    for line in text.splitlines():
        if not line.startswith("[v1332] process-table sample="):
            continue
        number = re.search(r"\bsample=(\d+)\b", line)
        matched = re.search(r"\bslot11=([A-Z]+)/([DR]):", line)
        if not number:
            raise AssertionError("missing physical process-table sample index")
        # Early boot snapshots can precede admission of PID 011. Require
        # its mapped state in *every fault-on* sample below, not before RUN.
        if not matched:
            continue
        index = int(number.group(1))
        if index in mapping:
            raise AssertionError("duplicate slot-011 process sample")
        mapping[index] = tuple(matched.groups())
    return mapping


def verify(samples, console, raw):
    V1509["verify"](samples, console, raw)
    active = [entry for entry in samples if entry.get("fault") == 1]
    if active[0]["slot"] == 0o11:
        raise AssertionError("healthy contender was chosen as failed owner")
    slots = slot11_states(raw)
    first_commit = None
    saw_disk_before = False
    saw_user_after = False
    prior = None
    for index, sample in enumerate(active):
        if not all(name in sample for name in (
                "contender_restore", "contender_exchange",
                "contender_sleep", "sample")):
            raise AssertionError("missing actual swapped contender witnesses")
        state = slots.get(sample["sample"])
        if not state or state[0] not in ("RUN", "SLEEP"):
            raise AssertionError("healthy contender is not a live process")
        restored = sample["contender_restore"]
        exchanged = sample["contender_exchange"]
        slept = sample["contender_sleep"]
        if any(value < 0 or value >= 0o100000 for value in (
                restored, exchanged, slept)):
            raise AssertionError("impossible swapped contender counter")
        committed = restored + exchanged
        if committed == 0:
            if slept:
                raise AssertionError("user ran before any checked restore")
            if state[1] == "D":
                saw_disk_before = True
        if prior is not None and (restored < prior[0] or
                exchanged < prior[1] or slept < prior[2]):
            raise AssertionError("swapped contender witness regressed")
        if committed > 0 and first_commit is None:
            if not saw_disk_before:
                raise AssertionError("no source-mapped prior DISK contender")
            first_commit = index
        if committed > 0 and slept:
            saw_user_after = True
        prior = (restored, exchanged, slept)
    if first_commit is None:
        raise AssertionError("no real checked restore/exchange after fault")
    if not saw_user_after or active[-1]["contender_sleep"] < 2:
        raise AssertionError("restored contender did not execute user syscalls")
    if (first_commit == len(active) - 1 or
            active[-1]["contender_sleep"] <=
            active[first_commit]["contender_sleep"]):
        raise AssertionError("no sustained user progress after restore")
    print("PASS v1510: distinct DISK slot 011 committed real swap-in="
          "%d exchange=%d after fault" % (
              active[-1]["contender_restore"],
              active[-1]["contender_exchange"]))
    print("PASS v1510: restored slot 011 subsequently executed %d"
          " real SLEEP syscalls" % active[-1]["contender_sleep"])
    print("PASS v1510: original failed DISK owner, pending TERM and"
          " healthy resident PID5 still preserved")


def self_test():
    owner = {
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
    for index in range(6):
        entry = dict(owner)
        entry.update({"sample": index + 20, "timer": index * 0o200,
                      "refused": index + 1,
                      "record_count": index + 1,
                      "failed_service": index + 1,
                      "spinner": index * 8 + 14,
                      "contender_restore": int(index >= 2),
                      "contender_exchange": 0,
                      "contender_sleep": max(0, (index - 2) * 3)})
        good.append(entry)
    # Early physical snapshots precede the candidate's admission and
    # legitimately omit slot 011; fault-on snapshots may never omit it.
    table = ("[v1332] process-table sample=1 "
             "slot05=SLEEP/R:064000:400401\n" + "\n".join(
        "[v1332] process-table sample=%d "
        "slot05=SLEEP/R:064000:400401 slot11=SLEEP/%s:064000:400401" %
        (item["sample"], "D" if index < 2 else "R")
        for index, item in enumerate(good)))
    with tempfile.NamedTemporaryFile(mode="w", delete=True) as console:
        verify(good, console.name, table)
        bad_cases = []
        for label, field, index, value in (
            ("no-restore", "contender_restore", 2, 0),
            ("fake-user", "contender_sleep", 1, 1),
            ("no-progress", "contender_sleep", 5, 0),
            ("regressed-restore", "contender_restore", 3, 0),
            ("missing-counter", "contender_sleep", 4, None),
            ("owner-corrupted", "record", 3, 0),
            ("false-ready", "cursor", 3, 0o1010),
            ("wrong-owner", "slot", 3, 9),
        ):
            copy = [dict(item) for item in good]
            if label == "no-restore":
                for item in copy[2:]:
                    item[field] = value
            elif value is None:
                copy[index].pop(field)
            else:
                copy[index][field] = value
            bad_cases.append((label, copy, table))
        bad_cases.extend((
            ("never-on-disk", good,
             table.replace("slot11=SLEEP/D", "slot11=SLEEP/R")),
            ("missing-live-slot", good,
             table.replace("slot11=SLEEP/D", "slot11=FREE/D", 1)),
            ("missing-table-slot", good,
             table.replace("slot11=", "slot12=", 1)),
        ))
        for label, samples, states in bad_cases:
            try:
                verify(samples, console.name, states)
            except AssertionError:
                continue
            raise AssertionError("v1510 accepted unsafe witness: " + label)
        print("PASS v1510: eleven strict physical witness mutations rejected")


def main():
    if sys.argv[1:] == ["--self-test"]:
        self_test()
        return
    if len(sys.argv) != 3:
        raise SystemExit("usage: v1510.py SAMPLER_LOG GUEST_CONSOLE")
    sampler, console = map(Path, sys.argv[1:])
    verify(V1508["load"](sampler), console,
           sampler.read_text(errors="replace"))


if __name__ == "__main__":
    main()
