#!/usr/bin/env python3
"""Test-only PDP-6 MM pin injection at an actual pinned FULL callback."""

from pathlib import Path
import hashlib
import re
import runpy
import sys


def expected(path):
    return dict((key, int(val, 8)) for key, val in re.findall(
        r"(?m)^([a-z0-9_]+)\s+([0-7]+)\s*$",
        path.read_text(encoding="ascii")))


def make(kit, build, probe, prior, out, dxrcheck):
    module = runpy.run_path(str(kit / "tests/validation/"
                    "pure-k05-secondary-physical-v1845/prepare-v1845.py"))
    stage_module = runpy.run_path(str(kit / "tests/diagnostics/"
                    "pure-full-restore-v1638/audit-v1638.py"))
    core = module["symbols"](build / "kcore.map")
    for name in ("mm_extents", "mm_extent_count", "proc_table",
                 "proc_sched_pi_tick", "proc_timer_clock", "proc_sched_cursor",
                 "proc_swap_pressure_ticks", "proc_current_slot"):
        if name not in core:
            raise ValueError("original fixed KCORE lacks " + name)
    # A previous actually executed 48K original FULL physical stage is
    # a layout oracle. It is NOT substituted for THIS new runtime read.
    sha = hashlib.sha256((build / "kcore.dxr").read_bytes()).hexdigest()
    if sha != "33bf700218a73fefcb36ebb1f1d835c1817f3a291a642898ccb3cbd5d9039d8b":
        raise ValueError("fixed KCORE differs from accepted physical v1848")
    old_trace = (prior / "physical.clean").read_text(encoding="ascii")
    block, extents = stage_module["stage"](
        old_trace.replace("V1845_", "V1638_"), core, "FULL_PINNED")
    match = [(start, end, kind, pin, owner) for start, end, kind, pin, owner
             in extents if owner == 3 and kind in (1, 4)]
    if sorted(match) != sorted([(0o111200, 0o120000, 4, 1, 3),
                               (0o120000, 0o130000, 1, 1, 3)]):
        raise ValueError("original physical slot3 FULL geometry changed")
    meta_addr = None
    for i in range(block[core["mm_extent_count"]]):
        address = core["mm_extents"] + i * 2
        span = block[address]
        meta = block[address + 1]
        if (span & 0o777777) == 0o120000 and \
                (span >> 18) == 0o10000 and \
                (meta & 0o777777) == 3 and \
                (meta >> 18) & 7 == 1:
            if ((meta >> 21) & 255) != 1 or meta_addr is not None:
                raise ValueError("original target pin count not unique")
            meta_addr = address + 1
            old_meta = meta
    if meta_addr is None:
        raise ValueError("original target descriptor not identified")
    installed = module["read_probe"](build, probe)
    module["physical"](build, out, installed, dxrcheck)
    physical = (out / "physical.ini").read_text(encoding="ascii")
    anchor = "echo V1845_END_FULL_PINNED\nnobreak\ndetach dtc3\n"
    if physical.count(anchor) != 1:
        raise ValueError("source-linked FULL checkpoint anchor moved")
    before, _ = physical.split(anchor, 1)
    old_values = expected(out / "expected-v1845.txt")
    new_meta = old_meta + (1 << 21)
    script = (before + "echo V1845_END_FULL_PINNED\n" +
        "nobreak\n" +
        "echo V1890_PHYSICAL_PREINJECT\n" +
        "examine %06o\n" % meta_addr +
        "echo V1890_END_PREINJECT\n" +
        "deposit %06o %012o\n" % (meta_addr, new_meta) +
        "echo V1890_PHYSICAL_SECOND_PIN\n" +
        "examine %06o\n" % meta_addr +
        "echo V1890_END_SECOND_PIN\n" +
        "break %06o\ncont\n" % old_values["service_return"] +
        "echo V1890_ORIGINAL_FULL_RETURN\nexamine 1\n" +
        module["snapshot"](core, "QUARANTINED") .replace(
            "V1845_", "V1890_") +
        "nobreak\nbreak %06o\ncont\n" % core["proc_sched_pi_tick"] +
        "echo V1890_REAL_CLOCK_AFTER_FAILURE\n" +
        "examine %06o\n" % core["proc_timer_clock"] +
        "examine %06o\n" % core["proc_swap_pressure_ticks"] +
        "examine %06o\n" % core["proc_sched_cursor"] +
        "examine %06o\n" % core["proc_table"] +
        module["snapshot"](core, "CLOCK_LATER").replace(
            "V1845_", "V1890_") +
        "exit\n")
    if script.count("deposit %06o %012o" % (meta_addr, new_meta)) != 1 \
            or "detach dtc3" in script:
        raise ValueError("unsafe duplicate injector or unintended DTC3 loss")
    (out / "physical.ini").write_text(script, encoding="ascii")
    (out / "expected-v1890.txt").write_text(
        ("target_meta_address %06o\nold_meta %012o\nnew_meta %012o\n"
         "target_base 120000\nsource_base 111200\nslot 000003\n"
         "return_pc %06o\npi6_pc %06o\n") % (
            meta_addr, old_meta, new_meta, old_values["service_return"],
            core["proc_sched_pi_tick"]), encoding="ascii")
    print("v1890: original physical target meta %06o pin1=%012o pin2=%012o"
          % (meta_addr, old_meta, new_meta))
    print("v1890: FULL entry %06o service-return %06o PCLK %06o" %
          (old_values["loader"], old_values["service_return"],
           core["proc_sched_pi_tick"]))


if __name__ == "__main__":
    if len(sys.argv) != 7:
        raise SystemExit("usage: prepare-v1890.py kit build probe prior-v1848 work dxrcheck")
    make(*(Path(x) for x in sys.argv[1:]))
