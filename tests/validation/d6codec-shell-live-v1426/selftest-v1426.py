#!/usr/bin/env python3
"""Host rejection controls for read-only SIMH physical DSH detection."""
import importlib.util
from pathlib import Path
import re

ROOT = Path(__file__).resolve().parents[3]
path = ROOT / "tests/validation/d6codec-shell-live-v1426/capture-v1426.py"
spec = importlib.util.spec_from_file_location("capture_v1426", path)
live = importlib.util.module_from_spec(spec)
spec.loader.exec_module(live)


class FakeConsole:
    def __init__(self, physical):
        self.physical = physical

    def command(self, text, timeout=18):
        match = re.fullmatch(r"ex ([0-7]+)(?:-([0-7]+))?", text)
        if not match:
            raise AssertionError("unexpected simulator command " + text)
        begin = int(match.group(1), 8)
        end = int(match.group(2), 8) if match.group(2) else begin
        return "".join(
            "%06o:\t%012o\n" % (p, self.physical.get(p, 0))
            for p in range(begin, end + 1)) + "sim> "


def rejects(call):
    try:
        call()
    except ValueError:
        return
    raise AssertionError("invalid simulator response was accepted")


def main():
    ptr = 0o200
    kmap = {"proc_table": 0o100, "proc_high_slot": 0o101,
            "proc_current_slot": 0o102}
    logical = {
        "_start": 0o20, "dsh_state_init": 0o21,
        "dsh_heap_alloc": 0o22, "dsh_execute_line": 0o23,
        "main": 0o24
    }
    payload = [((0o300000 + i) << 18) | i for i in range(5)]
    ram = {0o100: ptr, 0o101: 4, 0o102: 2}
    base = 0o40000
    vm = (18432 << 18) | base
    ram[ptr + 2 * 3 + 1] = vm
    ram[ptr + 2 * 3 + 2] = 2 << 33
    for i, name in enumerate(live.DSH_TEXT_SIGNATURE):
        ram[base + logical[name]] = payload[i] + base
    con = FakeConsole(ram)
    selected = live.find_shell(con, kmap, logical, payload, 5, 5)
    assert selected["base"] == base
    assert selected["slot"] == 2

    first = base + 0o20
    exact = con.command("ex %06o-%06o" % (first, first + 4))
    assert live.parse_examine(exact, first, 5) == [
        payload[i] + base for i in range(5)]
    rejects(lambda: live.parse_examine(exact, first, 6))
    rejects(lambda: live.parse_examine(exact + exact, first, 5))

    ram[base + logical["main"]] = 0
    rejects(lambda: live.find_shell(con, kmap, logical, payload, 5, 5))
    ram[base + logical["main"]] = payload[4] + base

    # A second indistinguishable resident DSH may exist. Never
    # choose a random slot or the first descriptor in this case.
    other = base + 0o50000
    ram[ptr + 3 * 3 + 1] = (18432 << 18) | other
    ram[ptr + 3 * 3 + 2] = 2 << 33
    for i, name in enumerate(live.DSH_TEXT_SIGNATURE):
        ram[other + logical[name]] = payload[i] + other
    rejects(lambda: live.find_shell(con, kmap, logical, payload, 5, 5))

    # Both the descriptor and the response parser must fail closed.
    ram[ptr + 3 * 3 + 1] = 0
    ram[ptr + 2 * 3 + 1] = (18432 << 18) | 0o777000
    rejects(lambda: live.find_shell(con, kmap, logical, payload, 5, 5))
    print("PASS v1426 simulated debugger rejection and unique DSH selection")


if __name__ == "__main__":
    main()
