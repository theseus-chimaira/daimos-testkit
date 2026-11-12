#!/usr/bin/env python3
"""Strict PDP-6 physical driver read-error and BACKSTORE ownership check.

Unlike v1508/v1510, v1511 includes failures BEFORE the checked free.
Track read failures and checked-free refusals separately; never relabel a
device error as a bitmap-free refusal to satisfy an older verifier.
"""

from pathlib import Path
import re
import runpy
import sys
import tempfile


HERE = Path(__file__).resolve().parent
BASE = runpy.run_path(str(HERE / "daimos-backstore-persistent-verify-v1508.py"))
PROGRESS = runpy.run_path(str(HERE / "daimos-backstore-swapped-verify-v1510.py"))
BYSTANDER = runpy.run_path(str(HERE / "daimos-backstore-bystander-verify-v1509.py"))


def verify(samples, console, table):
    active = [s for s in samples if s.get("fault") == 1]
    if len(active) < 6:
        raise AssertionError("insufficient physical fault-on samples")
    slot, first, blocks = (active[0][key] for key in ("slot", "first", "blocks"))
    if slot < 0o10 or slot in (5, 0o11) or first <= 0 or blocks <= 0:
        raise AssertionError("wrong original BACKSTORE owner")
    slot05 = BYSTANDER["process_samples"](table)
    slot11 = PROGRESS["slot11_states"](table)
    previous = None
    disk_before = False
    first_restore = None
    for idx, s in enumerate(active):
        required = ("sample", "timer", "slot", "first", "blocks",
                    "record", "meta", "vm", "sched", "retry", "fdctl",
                    "refused", "device_errors", "dsk_errors",
                    "failed_service", "record_count", "spinner",
                    "contender_restore", "contender_exchange", "contender_sleep",
                    "swap_blocks", "backstore_blocks", "cursor", "repairs",
                    "owner_term", "private_close", "finish", "zombie")
        if any(key not in s for key in required):
            raise AssertionError("missing mapped physical evidence field")
        if (s["slot"], s["first"], s["blocks"]) != (slot, first, blocks):
            raise AssertionError("failed DISK owner identity changed")
        if s["record"] != (first << 18 | blocks):
            raise AssertionError("original allocated run changed")
        if s["meta"] & 0o600000 != 0o400000 or s["vm"] & 0o777777:
            raise AssertionError("u-area/transition/RESIDENT ownership lost")
        if (s["sched"] >> 33) & 7 != 2:
            raise AssertionError("bad owner no longer RUN/DISK")
        if not s["retry"] & (1 << 32) or s["retry"] & (1 << 35):
            raise AssertionError("retry mark absent or FINALIZE overwritten")
        if not s["fdctl"] & (0o4 << 18):
            raise AssertionError("pending TERM was consumed prematurely")
        if s["swap_blocks"] < blocks or s["backstore_blocks"] < blocks:
            raise AssertionError("original BACKSTORE accounting lost")
        if s["cursor"] & 0o377 == slot and s["cursor"] & 0o1000:
            raise AssertionError("false READY_ONCE for the failed owner")
        if any(s[name] for name in ("repairs", "owner_term", "private_close",
                                   "finish", "zombie")):
            raise AssertionError("unrepaired owner falsely finalized")
        if not 0 <= s["device_errors"] <= 2:
            raise AssertionError("wrong injected controller failure count")
        if s["dsk_errors"] < s["device_errors"]:
            raise AssertionError("DSK controller error accounting absent")
        if s["refused"] < 1 or s["record_count"] < 1:
            raise AssertionError("no real physical checked refusal")
        if (s["record_count"] != s["failed_service"] or
                s["record_count"] != s["refused"] + s["device_errors"]):
            raise AssertionError("driver failures did not reach real swap service")
        if slot05.get(s["sample"]) not in ("SLEEP", "RUN"):
            raise AssertionError("independent resident spinner disappeared")
        state = slot11.get(s["sample"])
        if not state or state[0] not in ("SLEEP", "RUN"):
            raise AssertionError("healthy swapped contender not present")
        restore = s["contender_restore"] + s["contender_exchange"]
        if restore == 0 and state[1] == "D":
            disk_before = True
        if restore and first_restore is None:
            if not disk_before:
                raise AssertionError("contender not proven DISK before restore")
            first_restore = idx
        if s["contender_sleep"] and not restore:
            raise AssertionError("healthy contender ran without checked restore")
        if previous is not None:
            elapsed = (s["timer"] - previous["timer"]) & 0o377777
            failures = s["record_count"] - previous["record_count"]
            if elapsed <= 0 or failures < 0 or failures > elapsed // 0o100 + 4:
                raise AssertionError("failed owner retries faster than PI6 clock")
            if s["spinner"] <= previous["spinner"]:
                raise AssertionError("independent PID5 stopped running")
            for field in ("device_errors", "dsk_errors", "refused",
                          "contender_restore", "contender_exchange",
                          "contender_sleep"):
                if s[field] < previous[field]:
                    raise AssertionError("physical witness regressed: " + field)
        previous = s
    if active[-1]["device_errors"] != 2:
        raise AssertionError("both Type-270 controller failure paths unexercised")
    if active[-1]["refused"] - active[0]["refused"] < 2:
        raise AssertionError("checked release refusal did not resume")
    if active[-1]["record_count"] - active[0]["record_count"] < 3:
        raise AssertionError("no sustained real BACKSTORE failure")
    if first_restore is None or first_restore >= len(active) - 1:
        raise AssertionError("no successful healthy swapped restore")
    if (active[-1]["contender_sleep"] <=
            active[first_restore]["contender_sleep"] or
            active[-1]["contender_sleep"] < 2):
        raise AssertionError("healthy restored process did not execute")
    if "HALT instruction" in Path(console).read_text(errors="replace"):
        raise AssertionError("unrepaired owner guest claimed normal HALT")
    print("PASS v1511: real Type-270 PI5 driver error returned twice")
    print("PASS v1511: failed DISK owner %03o, extent %06o/%06o retained" %
          (slot, first, blocks))
    print("PASS v1511: %d real fault-on samples; %d driver errors, %d free refusals" %
          (len(active), active[-1]["device_errors"], active[-1]["refused"]))
    print("PASS v1511: PID5 and swapped PID011 progress under read/free failure")


def self_test():
    base = {
        "fault": 1, "slot": 8, "first": 0o2350, "blocks": 0o330,
        "record": (0o2350 << 18) | 0o330, "meta": 0o400000,
        "vm": 0o330 << 18, "sched": 2 << 33,
        "retry": 1 << 32, "fdctl": 0o4 << 18,
        "cursor": 0o410, "swap_blocks": 0o1000,
        "backstore_blocks": 0o1000, "repairs": 0,
        "owner_term": 0, "private_close": 0,
        "finish": 0, "zombie": 0,
    }
    good = []
    for index in range(7):
        s = dict(base)
        s.update({
            "sample": index + 20, "timer": index * 0o1000,
            "refused": max(1, index - 1),
            "device_errors": min(2, index),
            "dsk_errors": min(2, index),
            "spinner": 20 + index * 20,
            "contender_restore": int(index >= 3),
            "contender_exchange": 0,
            "contender_sleep": max(0, index - 3) * 10,
        })
        s["record_count"] = s["refused"] + s["device_errors"]
        s["failed_service"] = s["record_count"]
        good.append(s)
    table = "\n".join(
        "[v1332] process-table sample=%d slot05=SLEEP/R:064000:400401 "
        "slot11=SLEEP/%s:064000:400401" %
        (s["sample"], "D" if i < 3 else "R")
        for i, s in enumerate(good))
    with tempfile.NamedTemporaryFile(mode="w", delete=True) as log:
        verify(good, log.name, table)
        mutations = (
            ("device-count", "device_errors", 3, 0),
            ("controller-accounting", "dsk_errors", 2, 0),
            ("missing-rollback", "vm", 3, 1),
            ("backing-loss", "swap_blocks", 3, 0),
            ("wrong-run", "record", 3, 0),
            ("false-ready", "cursor", 3, 0o1010),
            ("lost-term", "fdctl", 3, 0),
            ("premature-zombie", "zombie", 4, 1),
            ("no-progress", "contender_sleep", 6, 0),
            ("silent-error", "failed_service", 2, 0),
            ("fast-retry", "record_count", 4, 100),
        )
        for label, field, at, bad in mutations:
            seq = [dict(s) for s in good]
            seq[at][field] = bad
            try:
                verify(seq, log.name, table)
            except AssertionError:
                continue
            raise AssertionError("v1511 accepted unsafe evidence: " + label)
        print("PASS v1511: eleven strict physical evidence mutations rejected")


def main():
    if sys.argv[1:] == ["--self-test"]:
        self_test()
        return
    if len(sys.argv) != 3:
        raise SystemExit("usage: v1511.py SAMPLER_LOG GUEST_CONSOLE")
    log, console = (Path(path) for path in sys.argv[1:])
    verify(BASE["load"](log), console, log.read_text(errors="replace"))


if __name__ == "__main__":
    main()
