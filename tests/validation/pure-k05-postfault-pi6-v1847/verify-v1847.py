#!/usr/bin/env python3
"""Verify real PI6 entry after failed FULL loader and exact MM rollback."""

from pathlib import Path
import re
import runpy
import sys


def capture_word(text, addr):
    words = re.findall(r"(?m)^%o:\s*([0-7]{12})\s*$" % addr, text)
    if len(words) != 1:
        raise ValueError("missing/duplicate original physical word %o" % addr)
    return int(words[0], 8)


def verify(kit, build, work):
    # Independently require every source/loader/MM/WAIT oracle already
    # accepted in v1845; PI6 is additional, not a substitute.
    old = runpy.run_path(str(kit / "tests/validation/"
                               "pure-k05-secondary-physical-v1845/"
                               "verify-v1845.py"))
    old["run"](kit, build, work)
    parser = runpy.run_path(str(kit / "tests/diagnostics/"
                                  "pure-full-restore-v1638/audit-v1638.py"))
    stage = parser["stage"]
    core = parser["symbols"]((build / "kcore.map").read_text(
        encoding="ascii"))
    data = (work / "physical.clean").read_text(encoding="ascii")
    expected = dict((key, int(value, 8)) for key, value in re.findall(
        r"(?m)^([a-z0-9_]+)\s+([0-7]+)\s*$",
        (work / "expected-pi6-v1847.txt").read_text(encoding="ascii")))
    pc, opcode = expected["pi6_pc"], expected["pi6_opcode"]
    if pc != core["proc_sched_pi_tick"]:
        raise ValueError("PI6 PC differs from linked fixed KCORE")
    if len(re.findall(r"Breakpoint, PC: %06o " % pc, data)) != 1:
        raise ValueError("real original PI6 entry was not reached exactly once")
    first = "V1845_END_ROLLED_BACK\n"
    middle = "V1847_ORIGINAL_PI6_CLOCK\n"
    last = "V1845_SAME_DTC3_REATTACHED\n"
    for marker in (first, middle, "V1847_STAGE_PI6_POSTFAIL\n",
                   "V1847_END_PI6_POSTFAIL\n", last):
        if data.count(marker) != 1:
            raise ValueError("missing/duplicate clock witness " + marker.strip())
    if not data.index(first) < data.index(middle) < data.index(last):
        raise ValueError("clock did not interrupt after rollback before reattach")
    regs = data.split(middle, 1)[1].split(
        "V1847_STAGE_PI6_POSTFAIL\n", 1)[0]
    if capture_word(regs, pc) != opcode:
        raise ValueError("physical PI6 instruction differs from KCORE DXR")
    clock = capture_word(regs, core["proc_timer_clock"])
    pressure = capture_word(regs, core["proc_swap_pressure_ticks"])
    cursor = capture_word(regs, core["proc_sched_cursor"])
    if pressure > 0o100:
        raise ValueError("PI6 found out-of-range PURE cooldown counter")
    if cursor & 0o400:
        raise ValueError("PI6 reentered still-active slot-0 service")
    # Check the *original* PDP-6 physical owner descriptor table at
    # the PI6 stop. The same full snapshot is independently parsed
    # before the interrupt, inside the handler, and after WAIT/HALT.
    first_words, first_mm = stage(data.replace("V1845_", "V1638_"),
                                  core, "ROLLED_BACK")
    irq_words, irq_mm = stage(data.replace("V1847_", "V1638_"),
                              core, "PI6_POSTFAIL")
    if first_words[core["proc_current_slot"]] != 0 or \
            irq_words[core["proc_current_slot"]] != 0:
        raise ValueError("PI6 not executing in slot-0 restore context")
    if irq_words[core["vfs_namespace_root"]] != \
            first_words[core["vfs_namespace_root"]]:
        raise ValueError("selected TSFS root changed in PI6")
    if irq_mm != first_mm:
        raise ValueError("PI6 entry changed a retained physical MM owner")
    children = [(lo, hi, kind, pin, slot) for lo, hi, kind, pin, slot in irq_mm
                if 2 <= slot <= 6 and kind in (1, 4)]
    if any(pin or kind != 4 for _, _, kind, pin, _ in children):
        raise ValueError("PI6 saw a pinned or premature runnable child APR")
    if not any((lo, hi, kind, pin, slot) ==
               (0o111200, 0o120000, 4, 0, 3) for lo, hi, kind, pin, slot
               in children):
        raise ValueError("PI6 lost exact secondary-backed source suffix")
    print("PASS v1847: actual fixed-KCORE PI6 %06o, original opcode %012o" %
          (pc, opcode))
    print("v1847: clock %o, cooldown %o, cursor %o; RAW owner/pins unchanged" %
          (clock, pressure, cursor))
    print("v1847: TSFS ROOT unchanged; later child recovery requires reel return")


def main(argv):
    if len(argv) != 4:
        raise SystemExit("usage: verify-v1847.py kit build original-evidence")
    try:
        verify(*(Path(s) for s in argv[1:]))
    except (AssertionError, ValueError, KeyError, OSError, UnicodeError) as e:
        raise SystemExit("FAIL v1847 original physical postfault PI6: " + str(e))


if __name__ == "__main__":
    main(sys.argv)
