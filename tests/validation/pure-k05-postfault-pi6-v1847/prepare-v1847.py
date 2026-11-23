#!/usr/bin/env python3
"""Create a genuine fixed-KCORE PI6 checkpoint after FULL source loss."""

from pathlib import Path
import os
import re
import runpy
import sys


def prepare(kit, build, probe, work, dxrcheck):
    original = runpy.run_path(str(
        kit / "tests/validation/pure-k05-secondary-physical-v1845/"
              "prepare-v1845.py"))
    base = original["read_probe"](build, probe)
    original["physical"](build, work, base, dxrcheck)
    core = original["symbols"](build / "kcore.map")
    for name in ("proc_sched_pi_tick", "proc_timer_clock",
                 "proc_swap_pressure_ticks", "proc_sched_cursor"):
        if name not in core:
            raise ValueError("missing original fixed KCORE: " + name)
    tick = core["proc_sched_pi_tick"]
    # The source-built KCORE DXR is packaged for KINIT and its IMAGE
    # positions are not permanent installed KCORE word addresses.
    # Derive the expected FIRST instruction from the original KCORE
    # assembler and its linked proc_timer_clock symbol, then verify it
    # against the independently examined real physical word at PI6.
    checkout = Path(os.environ["DAIMOS_REPO"])
    source = (checkout / "system/kernel/proc/proc_pdp6.s").read_text(
        encoding="ascii")
    if source.count("proc_sched_pi_tick:") != 1:
        raise ValueError("missing original proc_sched_pi_tick source")
    first = source.split("proc_sched_pi_tick:", 1)[1].splitlines()[:18]
    if len(re.findall(r"(?m)^\s*aos\s+1,proc_timer_clock\s*$",
                      "\n".join(first))) != 1:
        raise ValueError("original PCLK tick first opcode changed")
    if core["proc_timer_clock"] & ~0o777777:
        raise ValueError("original PCLK address cannot be PDP-10 EA")
    opcode = 0o350040000000 | core["proc_timer_clock"]
    # Linker-relocated PURE MRES instructions may not remain at the same
    # address after unload/reload. Observe only the permanent physical
    # KCORE PI6 PC after the initial source-linked FULL rollback.
    source = (work / "physical.ini").read_text(encoding="ascii")
    marker = "echo V1845_END_ROLLED_BACK\nnobreak\nattach -q dtc3 "
    if source.count(marker) != 1:
        raise ValueError("original physical FULL rollback anchor changed")
    replacement = ("echo V1845_END_ROLLED_BACK\n"
                   "nobreak\nbreak %06o\ncont\n" % tick +
                   "echo V1847_ORIGINAL_PI6_CLOCK\n"
                   "examine %06o\n" % tick +
                   "examine %06o\n" % core["proc_timer_clock"] +
                   "examine %06o\n" % core["proc_swap_pressure_ticks"] +
                   "examine %06o\n" % core["proc_sched_cursor"] +
                   original["snapshot"](core, "PI6_POSTFAIL").replace(
                       "V1845_", "V1847_") +
                   "nobreak\nattach -q dtc3 ")
    result = source.replace(marker, replacement, 1)
    if result == source or result.count("detach dtc3\n") != 1 or \
            result.count("attach -q dtc3 ") != 2:
        raise ValueError("unexpected original DTC3 attachment topology")
    (work / "physical.ini").write_text(result, encoding="ascii")
    (work / "expected-pi6-v1847.txt").write_text(
        "pi6_pc %06o\npi6_opcode %012o\n" % (tick, opcode),
        encoding="ascii")
    print("v1847: original fixed KCORE PI6 tick PC %06o opcode %012o" %
          (tick, opcode))


def main(argv):
    if len(argv) != 6:
        raise SystemExit("usage: prepare-v1847.py kit build probe work dxrcheck")
    prepare(*(Path(s) for s in argv[1:]))


if __name__ == "__main__":
    main(sys.argv)
