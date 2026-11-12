#!/usr/bin/env python3
"""Strict physical lost-Type236-completion -> real PI6 timeout acceptance.

The original v1511 field device_errors is zero here: no selected PI2 error
is published. The separate source-linked v1512 watchdog_errors increments
only at the original PI6 deadline; normalize that field solely for reuse of
v1511's exact DISK/MM/TERM/healthy-contender ownership verifier.
"""

from pathlib import Path
from contextlib import redirect_stdout
import io
import re
import runpy
import sys
import tempfile


HERE = Path(__file__).resolve().parent
BASE = runpy.run_path(str(HERE / "daimos-backstore-persistent-verify-v1508.py"))
V1511 = runpy.run_path(str(HERE / "daimos-backstore-device-error-verify-v1511.py"))


def load(path):
    """Preserve original octal decoding and the v1512 digit-bearing name."""
    data = BASE["load"](path)
    lost = []
    for line in Path(path).read_text(errors="replace").splitlines():
        if not line.startswith("[v1306] sample="):
            continue
        match = re.search(r"(?:^|\s)lost_pi2=(\d+)(?:\s|$)", line)
        if match is None:
            raise AssertionError("v1512 missing raw lost_pi2 observation")
        lost.append(int(match.group(1)))
    if len(data) != len(lost):
        raise AssertionError("v1512 mismatched mapped sample count")
    for record, count in zip(data, lost):
        record["lost_pi2"] = count
    return data


def verify(samples, console, table):
    active = [s for s in samples if s.get("fault") == 1]
    if len(active) < 6:
        raise AssertionError("not enough physical lost-completion samples")
    normal = []
    before = None
    for item in samples:
        s = dict(item)
        if item.get("fault") == 1:
            for name in ("lost_pi2", "watchdog_errors", "device_errors"):
                if name not in s:
                    raise AssertionError("missing genuine timeout field: " + name)
            if s["device_errors"] != 0:
                raise AssertionError("v1512 accidentally delivered PI2 error")
            lost = s["lost_pi2"]
            timed = s["watchdog_errors"]
            if not 0 <= timed <= lost <= 2:
                raise AssertionError("lost completion/real watchdog mismatch")
            if before:
                if lost < before["lost_pi2"] or timed < before["watchdog_errors"]:
                    raise AssertionError("real watchdog witness regressed")
            before = s
        # v1511 accepts both rejected checked releases and real device
        # read failures as negative slot-0 completions. The PI6 timeout
        # is the latter, but never masquerades as a PI2-error witness.
        s["device_errors"] = s.get("watchdog_errors", 0)
        normal.append(s)
    if active[-1]["lost_pi2"] != 2 or active[-1]["watchdog_errors"] != 2:
        raise AssertionError("two real lost completions not timed out")
    # This inherited checker verifies physical DISK extent, stable u-area,
    # MM owner, retry cadence, TERM and two genuine healthy processes.
    with redirect_stdout(io.StringIO()):
        V1511["verify"](normal, console, table)
    print("PASS v1512: two Type-236 DR_DONE publications suppressed")
    print("PASS v1512: both original PI6 300-tick watchdogs published errors")
    print("PASS v1512: selected DISK ownership and independent real users intact")


def self_test():
    base = {
        "fault": 1, "slot": 8, "first": 0o2350, "blocks": 0o330,
        "record": (0o2350 << 18) | 0o330, "meta": 0o400000,
        "vm": 0o330 << 18, "sched": 2 << 33,
        "retry": 1 << 32, "fdctl": 0o4 << 18,
        "cursor": 0o410, "swap_blocks": 0o1000,
        "backstore_blocks": 0o1000, "repairs": 0,
        "owner_term": 0, "private_close": 0,
        "finish": 0, "zombie": 0, "device_errors": 0,
    }
    seq = []
    for index in range(7):
        rec = dict(base)
        rec.update({
            "sample": index + 20, "timer": index * 0o1000,
            "refused": max(1, index - 1),
            "lost_pi2": min(2, index),
            "watchdog_errors": min(2, index),
            "drm_errors": min(2, index),
            "spinner": 20 + index * 20,
            "contender_restore": int(index >= 3),
            "contender_exchange": 0,
            "contender_sleep": max(0, index - 3) * 10,
        })
        rec["record_count"] = rec["refused"] + rec["watchdog_errors"]
        rec["failed_service"] = rec["record_count"]
        seq.append(rec)
    table = "\n".join(
        "[v1332] process-table sample=%d slot05=SLEEP/R:064000:400401 "
        "slot11=SLEEP/%s:064000:400401" %
        (record["sample"], "D" if i < 3 else "R")
        for i, record in enumerate(seq))
    with tempfile.NamedTemporaryFile(mode="w", delete=True) as log:
        verify(seq, log.name, table)
        mutations = (
            ("unaccounted-loss", "lost_pi2", 2, 0),
            ("false-watchdog", "watchdog_errors", 3, 3),
            ("lost-progress", "lost_pi2", 6, 1),
            ("missing-watchdog", "watchdog_errors", 6, 1),
            ("PI2-not-lost", "device_errors", 3, 1),
            ("controller-accounting", "drm_errors", 4, 0),
            ("disk-free", "record", 4, 0),
            ("MM-leak", "vm", 4, 1),
            ("lost-term", "fdctl", 4, 0),
            ("false-restore", "cursor", 4, 0o1010),
            ("lost-bystander", "contender_sleep", 6, 0),
            ("failure-accounting", "record_count", 4, 0),
        )
        for label, name, idx, value in mutations:
            changed = [dict(s) for s in seq]
            changed[idx][name] = value
            try:
                verify(changed, log.name, table)
            except AssertionError:
                continue
            raise AssertionError("v1512 accepted false evidence: " + label)
        # The inherited v1508 key parser intentionally recognizes only
        # [a-z_]; a v1512 loss counter includes the digit 2. Ensure the
        # raw SIMH text is not silently accepted without that counter.
        with tempfile.NamedTemporaryFile(mode="w", delete=True) as raw:
            raw.write("[v1306] sample=1 fault=1 lost_pi2=2 watchdog_errors=1 "
                      "record=002350000330\n")
            raw.flush()
            parsed = load(raw.name)
            if parsed[0]["lost_pi2"] != 2 or parsed[0]["record"] != (
                    (0o2350 << 18) | 0o330):
                raise AssertionError("v1512 lost exact octal or digit key")
            raw.seek(0)
            raw.truncate()
            raw.write("[v1306] sample=1 fault=1 watchdog_errors=1\n")
            raw.flush()
            try:
                load(raw.name)
            except AssertionError:
                pass
            else:
                raise AssertionError("v1512 accepted missing PI2 loss witness")
        print("PASS v1512: twelve unsafe physical evidence mutations rejected")
        print("PASS v1512: digit-bearing lost_pi2 parser and missing-key test")


def main():
    if sys.argv[1:] == ["--self-test"]:
        self_test()
        return
    if len(sys.argv) != 3:
        raise SystemExit("usage: v1512.py SAMPLER_LOG GUEST_CONSOLE")
    log, console = (Path(s) for s in sys.argv[1:])
    verify(load(log), console, log.read_text(errors="replace"))


if __name__ == "__main__":
    main()
