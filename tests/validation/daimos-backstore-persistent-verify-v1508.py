#!/usr/bin/env python3
"""Strict scoped physical snapshots of permanently refused BACKSTORE.

This is a bounded diagnostic; no HALT/EXIT acceptance can be claimed
while the selected process still owns an unrepairable DISK run.
"""

from pathlib import Path
import re
import sys
import tempfile


OCTAL = ("record", "meta", "vm", "sched", "retry", "fdctl", "cursor", "runq")


def load(path):
    snapshots = []
    for line in Path(path).read_text(errors="replace").splitlines():
        if not line.startswith("[v1306] sample="):
            continue
        pairs = re.findall(r"([a-z_]+)=([0-9]+)", line)
        values = {key: int(val, 8 if key in OCTAL else 10)
                  for key, val in pairs}
        snapshots.append(values)
    return snapshots


def verify(samples, console):
    if len(samples) < 5:
        raise AssertionError("insufficient source-linked physical samples")
    active = [s for s in samples if s.get("fault", 0) == 1]
    if len(active) < 3:
        raise AssertionError("no sustained selected physical refusal")
    slot, first, blocks = (
        active[0][key] for key in ("slot", "first", "blocks"))
    if not 8 <= slot < 64 or first <= 0 or blocks <= 0:
        raise AssertionError("invalid selected DISK owner")
    prev = None
    for sample in active:
        if (sample["slot"], sample["first"], sample["blocks"]) != (
                slot, first, blocks):
            raise AssertionError("selected original backing changed")
        if sample["repairs"] or sample["owner_term"] or sample[
                "private_close"] or sample["finish"] or sample["zombie"]:
            raise AssertionError("owner finalized or injector repaired")
        if sample["record_count"] <= 0:
            raise AssertionError("no matching physical failed-service witness")
        if sample["record"] != ((first << 18) | blocks):
            raise AssertionError("authoritative DISK run identity changed")
        if sample["meta"] & 0o600000 != 0o400000:
            raise AssertionError("stable u-area or transition invariant")
        if sample["vm"] & 0o777777:
            raise AssertionError("false physical RESIDENT state")
        if (sample["sched"] >> 33) & 7 != 2:
            raise AssertionError("owner lost RUN state unexpectedly")
        if not sample["retry"] & (1 << 32):
            raise AssertionError("nonresident owner retry tag missing")
        if sample["retry"] & (1 << 35):
            raise AssertionError("retry stamp overwrote FINALIZE owner")
        if not sample["fdctl"] & (0o4 << 18):
            raise AssertionError("pending TERM unexpectedly consumed")
        if prev:
            elapsed = (sample["timer"] - prev["timer"]) & 0o377777
            refused = sample["refused"] - prev["refused"]
            if elapsed < 1 or refused < 0:
                raise AssertionError("clock or refusal did not progress")
            # Bounded retries use the actual 0100-octal-tick interval.
            # Allow scheduler quantization, sampling overhead and a
            # non-clock-triggered manual attempt at either edge.
            if refused > elapsed // 0o100 + 4:
                raise AssertionError("retries outpaced PI6 clock cooldown")
        prev = sample
    if active[-1]["refused"] - active[0]["refused"] < 2:
        raise AssertionError("no repeated actual checked refusals")
    if active[-1]["timer"] == active[0]["timer"]:
        raise AssertionError("no physical timer progress under fault")
    if "HALT instruction" in Path(console).read_text(errors="replace"):
        raise AssertionError("guest claimed HALT despite permanent owner")
    print("PASS v1508: physical selected DISK slot=%03o first=%06o"
          " count=%06o retained" % (slot, first, blocks))
    print("PASS v1508: %d real fault-on samples, checked refusals %d..%d"
          % (len(active), active[0]["refused"], active[-1]["refused"]))
    print("PASS v1508: clock-bounded retry, pending TERM, stable u-area")
    print("PASS v1508: no false RESIDENT/finalize/repair; diagnostic only")


def main():
    if sys.argv[1:] == ["--self-test"]:
        base = {
            "fault": 1, "slot": 8, "first": 0o2350, "blocks": 0o330,
            "repairs": 0, "owner_term": 0, "private_close": 0,
            "finish": 0, "zombie": 0, "record_count": 1,
            "record": (0o2350 << 18) | 0o330,
            "meta": 0o400000, "vm": 0o330 << 18,
            "sched": 2 << 33,
            "retry": (1 << 32), "fdctl": 0o4 << 18,
        }
        good = []
        for index in range(5):
            values = dict(base)
            values["timer"] = (0o377700 + index * 0o100) & 0o377777
            values["refused"] = index + 1
            good.append(values)
        with tempfile.NamedTemporaryFile(mode="w", suffix="-v1508.txt",
                                         delete=True) as tmp:
            verify(good, tmp.name)
            for field, bad in (
                ("record", 0), ("meta", 0), ("vm", 1),
                ("sched", 0), ("retry", 0),
                ("fdctl", 0), ("owner_term", 1),
                ("repairs", 1), ("zombie", 1)):
                mutated = [dict(entry) for entry in good]
                mutated[2][field] = bad
                try:
                    verify(mutated, tmp.name)
                except AssertionError:
                    continue
                raise AssertionError(
                    "v1508 validator accepted unsafe mutation: " + field)
            mutated = [dict(entry) for entry in good]
            mutated[3]["refused"] = 100
            try:
                verify(mutated, tmp.name)
            except AssertionError:
                pass
            else:
                raise AssertionError("v1508 accepted uncontrolled retry")
        print("PASS v1508: ten strict validator mutations rejected")
        return
    if len(sys.argv) != 3:
        raise SystemExit("usage: v1508.py SAMPLER_LOG GUEST_CONSOLE")
    verify(load(sys.argv[1]), sys.argv[2])


if __name__ == "__main__":
    main()
