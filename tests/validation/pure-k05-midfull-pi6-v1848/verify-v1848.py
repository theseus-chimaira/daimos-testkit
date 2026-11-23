#!/usr/bin/env python3
"""Prove real PDP-6 PI6 interrupt while BOTH original FULL MM pins live."""

from pathlib import Path
import re
import runpy
import sys


def word(section, addr):
    matches = re.findall(r"(?m)^%o:\s*([0-7]{12})\s*$" % addr,
                         section)
    if len(matches) != 1:
        raise ValueError("missing/duplicate physical PDP-6 word %o" % addr)
    return int(matches[0], 8)


def verify(kit, build, work):
    old = runpy.run_path(str(
        kit / "tests/validation/pure-k05-secondary-physical-v1845/"
              "verify-v1845.py"))
    old["run"](kit, build, work)
    parser = runpy.run_path(str(
        kit / "tests/diagnostics/pure-full-restore-v1638/audit-v1638.py"))
    original = parser["stage"]
    core = parser["symbols"]((build / "kcore.map").read_text(
        encoding="ascii"))
    trace = (work / "physical.clean").read_text(encoding="ascii")
    expected = dict((key, int(val, 8)) for key, val in re.findall(
        r"(?m)^([a-z0-9_]+)\s+([0-7]+)\s*$",
        (work / "expected-pi6-v1847.txt").read_text(encoding="ascii")))
    saved = dict((key, int(val, 8)) for key, val in re.findall(
        r"(?m)^([a-z0-9_]+)\s+([0-7]+)\s*$",
        (work / "expected-pi6-v1848.txt").read_text(encoding="ascii")))
    pc, opcode = expected["pi6_pc"], expected["pi6_opcode"]
    if pc != saved["pi6_pc"] or pc != core["proc_sched_pi_tick"] or \
            saved["pi6_save"] != core["pdp10_pi_level6"]:
        raise ValueError("original PI6 KCORE map is not source matched")
    markers = ("V1845_END_FULL_PINNED\n",
               "V1848_ORIGINAL_PI6_CLOCK\n",
               "V1848_STAGE_PI6_MIDFULL\n",
               "V1848_END_PI6_MIDFULL\n",
               "V1845_DTC3_DETACHED\n",
               "V1845_FAILED_FULL_RETURN\n",
               "V1845_SAME_DTC3_REATTACHED\n")
    for item in markers:
        if trace.count(item) != 1:
            raise ValueError("missing/duplicate original physical marker: " +
                             item.strip())
    positions = [trace.index(item) for item in markers]
    if positions != sorted(positions):
        raise ValueError("PI6 did not interrupt INSIDE pinned FULL before detach")
    if len(re.findall(r"Breakpoint, PC: %06o " % pc, trace)) != 1:
        raise ValueError("real original PCLK PI6 entry not uniquely reached")
    before = trace.split("V1848_ORIGINAL_PI6_CLOCK\n", 1)[1].split(
        "V1848_STAGE_PI6_MIDFULL\n", 1)[0]
    if word(before, pc) != opcode:
        raise ValueError("physical PI6 tick opcode differs from original KCORE")
    interrupted = word(before, core["pdp10_pi_level6"])
    interrupted_pc = interrupted & 0o777777
    if not interrupted_pc or interrupted_pc == pc:
        raise ValueError("PI6 saved interrupt PC missing/invalid")
    if interrupted & (0o10000 << 18):
        raise ValueError("PI6 interrupted USER instead of slot-0 FULL")
    old_expected = dict((key, int(val, 8)) for key, val in re.findall(
        r"(?m)^([a-z0-9_]+)\s+([0-7]+)\s*$",
        (work / "expected-v1845.txt").read_text(encoding="ascii")))
    # The interrupted PC must belong to the installed PURE module,
    # whose actual base comes from the physically read KCORE reclaim
    # JRST. DXRCheck's abbreviated IMAGE dump cannot be used to infer
    # a module boundary, so bracket the offset in the ORIGINAL MRES map.
    offset = interrupted_pc - old_expected["base"]
    mres_map = parser["symbols"]((build / "pure-mres-v1612.map").read_text(
        encoding="ascii"))
    prior = [(addr, name) for name, addr in mres_map.items() if addr <= offset]
    later = [(addr, name) for name, addr in mres_map.items() if addr > offset]
    if not prior or not later:
        raise ValueError("PI6 saved PC outside original source-linked PURE MRES")
    origin = max(prior)
    clock = word(before, core["proc_timer_clock"])
    cooldown = word(before, core["proc_swap_pressure_ticks"])
    cursor = word(before, core["proc_sched_cursor"])
    if cursor & 0o400 or cooldown > 0o100:
        raise ValueError("PI6 found active swap request or invalid cooldown")
    first, mm_first = original(trace.replace("V1845_", "V1638_"),
                               core, "FULL_PINNED")
    irq, mm_irq = original(trace.replace("V1848_", "V1638_"),
                            core, "PI6_MIDFULL")
    for label, values in (("FULL", first), ("PI6", irq)):
        if values[core["proc_current_slot"]] != 0:
            raise ValueError(label + " is not executing from slot 0")
    if irq[core["vfs_namespace_root"]] != \
            first[core["vfs_namespace_root"]]:
        raise ValueError("selected TSFS ROOT changed during PI6")
    if irq[core["mm_extent_count"]] != \
            first[core["mm_extent_count"]] or mm_irq != mm_first:
        raise ValueError("PI6 entry changed pinned FULL MM descriptors")
    target = (0o120000, 0o130000, 1, 1, 3)
    source = (0o111200, 0o120000, 4, 1, 3)
    if mm_irq.count(source) != 1 or mm_irq.count(target) != 1:
        raise ValueError("PI6 did not interrupt while BOTH FULL pins held")
    if source[0] < target[1] and target[0] < source[1]:
        raise ValueError("pinned source and target overlap")
    print("PASS v1848: original PCLK PI6 physically interrupted pinned FULL")
    print("v1848: PI6 %06o opcode %012o, interrupted PC %06o" %
          (pc, opcode, interrupted_pc))
    print("v1848: interrupted original MRES offset %06o (at/after %s)" %
          (offset, origin[1]))
    print("v1848: two original MM pins retained, clock %o cooldown %o cursor %o" %
          (clock, cooldown, cursor))
    print("v1848: subsequent original DTC3 failure/rollback and 5 WAIT/HALT PASS")


def main(argv):
    if len(argv) != 4:
        raise SystemExit("usage: verify-v1848.py testkit build physical-evidence")
    try:
        verify(*(Path(s) for s in argv[1:]))
    except (AssertionError, ValueError, KeyError, OSError, UnicodeError) as exc:
        raise SystemExit("FAIL v1848 original physical PI6 inside FULL: " +
                         str(exc))


if __name__ == "__main__":
    main(sys.argv)
