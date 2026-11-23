#!/usr/bin/env python3
"""Physically exercise a genuine parent TERM(3) after RAW FULL -5."""

from pathlib import Path
import hashlib
import re
import runpy
import sys


def read_word(block, addr):
    found = re.findall(r"(?m)^%o:\s*([0-7]{12})\s*$" % addr, block)
    if len(found) != 1:
        raise ValueError("v1901 prior original physical word not unique: %06o" % addr)
    return int(found[0], 8)


def prepare(kit, build, probe, accepted, previous, work, dxrcheck, objdump):
    orig = runpy.run_path(str(kit / "tests/validation/"
                    "pure-k05-terminal-dual-owner-v1900/prepare-physical-v1900.py"))
    orig["prepare"](kit, build, probe, accepted, work, dxrcheck, objdump)
    init = (build.parent / "user/init-v1614.c").read_text(encoding="ascii")
    if init.count("SYS_PROCCTL_EVENT_PID") != 1 or \
            init.count("SYS_EVENT_ARG(3U, SYS_EVENT_TERM)") != 1 or \
            init.count("rc_v1901 == 0 ? 'A' : 'R'") != 1 or \
            init.count("v1901_term_gate == 012345670123UL") != 1:
        raise ValueError("actual guest is not the one-time user TERM(3) fixture")
    older = (previous / "physical.clean").read_text(encoding="ascii")
    old_expect = (previous / "expected-v1895.txt").read_text(encoding="ascii")
    matches = re.findall(r"(?m)^process_table\s+([0-7]+)$", old_expect)
    if len(matches) != 1:
        raise ValueError("accepted v1900 physical process-table oracle missing")
    table = int(matches[0], 8)
    if table != 0o45014:
        raise ValueError("accepted v1900 relocated table unexpectedly moved")
    stage = older.split("V1895_STAGE_HEARTBEAT_1\n", 1)[1].split(
        "V1895_END_HEARTBEAT_1\n", 1)[0]
    meta = read_word(stage, table + 9)
    uarea = meta >> 18
    if uarea == 0 or (meta & (1 << 16)) == 0 or \
            read_word(stage, table + 10) & 0o777777:
        raise ValueError("v1900 physical slot3 not exact nonrunnable transition")
    # Only the TEST-ONLY parent user APR has a writable enable word.
    # Its original VM base was already proved to be 130000 octal by
    # the accepted v1900 guest and is checked again in this v1901 run.
    parent_vm = read_word(stage, table + 4) & 0o777777
    user_map = runpy.run_path(str(kit / "tests/validation/"
                "pure-k05-secondary-physical-v1845/prepare-v1845.py"))[
                    "symbols"](build.parent / "user/init.map")
    if parent_vm != 0o130000 or "v1901_term_gate" not in user_map:
        raise ValueError("original resident parent or test-only user gate missing")
    user_gate = user_map["v1901_term_gate"]
    if not 0o20 < user_gate < 0o10000:
        raise ValueError("test-only gate must reside in parent user APR")
    physical_gate = parent_vm + user_gate
    gate_value = 0o12345670123
    core = runpy.run_path(str(kit / "tests/validation/"
                "pure-k05-secondary-physical-v1845/prepare-v1845.py"))[
                    "symbols"](build / "kcore.map")
    script = (work / "physical.ini").read_text(encoding="ascii")
    hb1_end = 'echo V1895_END_HEARTBEAT_1\n'
    if script.count(hb1_end) != 1:
        raise ValueError("original first HB actual context anchor missing")
    script = script.replace(hb1_end,
        'echo V1901_PRETERM_CONTEXT\n' +
        'examine %06o\n' % (uarea + 0o20) +
        'examine %06o\n' % (uarea + 0o24) +
        'examine %06o\n' % (uarea + 0o67) +
        'echo V1901_END_PRETERM_CONTEXT\n' + hb1_end, 1)
    # The original parent must not send TERM during early HBs.
    # Enable exactly one native user syscall only AFTER the physical
    # controller has observed the actual MM failure and first HBs.
    script = script.replace(hb1_end,
        hb1_end + 'echo V1901_USER_GATE_BEFORE\n' +
        'examine %06o\n' % physical_gate +
        'echo V1901_END_USER_GATE_BEFORE\n' +
        'deposit %06o %012o\n' % (physical_gate, gate_value) +
        'echo V1901_USER_GATE_ARMED\n' +
        'examine %06o\n' % physical_gate +
        'echo V1901_END_USER_GATE_ARMED\n', 1)
    anchor = ('expect "HB"\ncont\n'
              'echo V1895_ACTUAL_RESIDENT_HEARTBEAT_2\n')
    if script.count(anchor) != 1:
        raise ValueError("cannot locate second original parent HB marker")
    snapshot = ('expect "TR"\ncont\n'
                'echo V1901_ACTUAL_USER_TERM_REFUSED\n'
                'echo V1901_STAGE_TERM_REFUSED\n')
    for name in ("proc_table", "proc_current_slot", "proc_high_slot",
                 "mm_extent_count", "proc_timer_clock"):
        snapshot += 'examine %06o\n' % core[name]
    snapshot += ('examine %06o-%06o\n' % (table, table + 20) +
                 'examine %06o\n' % (uarea + 0o20) +
                 'examine %06o\n' % (uarea + 0o24) +
                 'examine %06o\n' % (uarea + 0o67) +
                 'examine %06o-%06o\n' %
                 (core['mm_extents'],core['mm_extents']+95) +
                 'echo V1901_END_TERM_REFUSED\n' +
                 'expect "HB"\ncont\n' +
                 'echo V1895_ACTUAL_RESIDENT_HEARTBEAT_2\n')
    script = script.replace(anchor, snapshot, 1)
    if script.count('expect "HB"\ncont\n') != 2 or \
            script.count('expect "TR"\ncont\n') != 1:
        raise ValueError("one original TERM oracle and two HB stages required")
    (work / "physical.ini").write_text(script, encoding="ascii")
    (work / "expected-v1901.txt").write_text(
        "table %06o\nuarea %06o\nslot 000003\n"
        "parent_base %06o\nuser_gate %06o\nphysical_gate %06o\n"
        "gate_value %012o\n" %
        (table,uarea,parent_vm,user_gate,physical_gate,gate_value),
        encoding="ascii")
    print("v1901: actual user PROCCTL TERM(3) after source MM-free -5")
    print("v1901: physical uarea=%06o saved ctx PC=%06o FDCTL=%06o FINAL=%06o" %
          (uarea,uarea+0o20,uarea+0o24,uarea+0o67))
    print("v1901: original parent APR=%06o, test-only user gate=%06o logical/%06o physical" %
          (parent_vm,user_gate,physical_gate))


if __name__ == "__main__":
    if len(sys.argv) != 9:
        raise SystemExit("usage: prepare-physical-v1901.py kit build probe old-v1895 accepted-v1900 work dxrcheck objdump")
    try:
        prepare(*(Path(s) for s in sys.argv[1:]))
    except (OSError, ValueError, AssertionError, KeyError) as e:
        raise SystemExit("FAIL v1901 genuine TERM controller: " + str(e))
