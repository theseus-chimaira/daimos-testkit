#!/usr/bin/env python3
"""Physical original PDP6 double genuine target mm_unpin -4 refusal."""

from pathlib import Path
import hashlib
import re
import runpy
import subprocess
import sys


def prepare(kit, build, probe, prior, work, dxrcheck, objdump):
    base = runpy.run_path(str(kit / "tests/validation/"
                       "pure-k05-secondary-physical-v1845/prepare-v1845.py"))
    audit = runpy.run_path(str(kit / "tests/diagnostics/"
                        "pure-full-restore-v1638/audit-v1638.py"))
    v1894 = runpy.run_path(str(kit / "tests/validation/"
                       "pure-k05-real-free-refusal-v1894/prepare-v1894.py"))
    guest = (build.parent / "user/init-v1614.c").read_text(encoding="ascii")
    for marker in ("(void)p14_char('H');", "(void)p14_char('B');",
                   "#define P14_CHILDREN         5U"):
        if guest.count(marker) != 1:
            raise ValueError("v1898 requires accepted resident-parent test guest")
    if guest.index("(void)p14_char('L');") >= guest.index(
            "(void)p14_char('H');"):
        raise ValueError("resident parent HB marker must follow child BRK/PIPE")
    v1894["read"](kit, build, probe, prior, work, dxrcheck, objdump)
    core = base["symbols"](build / "kcore.map")
    pure = base["symbols"](build / "pure-mres-v1612.map")
    physbase = base["read_probe"](build, probe)
    opcodes = base["source_words"](build, dxrcheck)
    obj = build / "proc_pure_full_v1611.dobj"
    symtab = subprocess.check_output([str(objdump), "-t", str(obj)],
                                     encoding="ascii")
    initial = re.findall(r"(?m)^\s*\d+ DEF\s+\.text\s+[0-7]{6},,"
                         r"([0-7]{6})\s+proc_pure_ram_restore_v1391\s*$", symtab)
    relocs = subprocess.check_output([str(objdump), "-r", str(obj)],
                                     encoding="ascii")
    offsets = [int(x, 8) for x in re.findall(
        r"(?m)^\.text\+([0-7]{6}) type=2 symbol=mm_unpin addend=", relocs)]
    if len(initial) != 1 or len(offsets) != 4 or offsets != sorted(offsets):
        raise ValueError("original compiled FULL unpin call offsets changed")
    origin = int(initial[0], 8)
    calls = [pure["proc_pure_ram_restore_v1391"] + offset - origin
             for offset in offsets]
    expected_opcode = 0o260740000000 | core["mm_unpin"]
    if any(opcodes.get(call) != expected_opcode for call in calls):
        raise ValueError("original linked FULL does not call real fixed mm_unpin")
    # First unpin is target at FULL commit. Third unpin is target
    # at fail_target. Second is source commit, fourth source failure.
    if offsets != [0o655, 0o662, 0o746, 0o766]:
        raise ValueError("original target/source unpin relocation order changed")
    target_call = calls[0] + physbase
    target_return = target_call + 1
    retry_call = calls[2] + physbase
    retry_return = retry_call + 1

    old = (prior / "physical.clean").read_text(encoding="ascii")
    pinned, extents = audit["stage"](old.replace("V1845_", "V1638_"),
                                     core, "FULL_PINNED")
    addr = []
    for i in range(pinned[core["mm_extent_count"]]):
        cell = core["mm_extents"] + 2 * i
        if pinned[cell] == ((0o10000 << 18) | 0o120000) and \
                pinned[cell + 1] == ((1 << 21) | (1 << 18) | 3):
            addr.append(cell + 1)
    if len(addr) != 1 or \
            extents.count((0o120000, 0o130000, 1, 1, 3)) != 1 or \
            extents.count((0o111200, 0o120000, 4, 1, 3)) != 1:
        raise ValueError("original physical pinned FULL owner pair changed")
    meta = addr[0]
    pin1 = pinned[meta]
    pin0 = pin1 - (1 << 21)
    text = (work / "physical.ini").read_text(encoding="ascii")
    anchor = "echo V1845_END_FULL_PINNED\nnobreak\nbreak "
    if text.count(anchor) != 1:
        raise ValueError("original physical pinned-FULL checkpoint changed")
    head, _ = text.split(anchor, 1)
    expected = dict((key, int(val, 8)) for key, val in re.findall(
        r"(?m)^([a-z0-9_]+)\s+([0-7]+)\s*$",
        (work / "expected-v1894.txt").read_text(encoding="ascii")))

    def snapshot(name):
        s = base["snapshot"](core, name).replace("V1845_", "V1898_")
        end = "echo V1898_END_%s\n" % name
        if not s.endswith(end):
            raise ValueError("original MM snapshot schema changed")
        return (s[:-len(end)] +
                "examine %06o\n" % core["proc_table"] +
                "examine 044712-044732\n" +
                "examine %06o\n" % core["proc_timer_clock"] + end)

    result = (head + "echo V1845_END_FULL_PINNED\n" +
        "nobreak\nbreak %06o\ncont\n" % target_call +
        "echo V1898_ORIGINAL_TARGET_UNPIN_CALL\n" +
        "examine %06o\n" % meta + snapshot("BEFORE_TARGET_UNPIN") +
        "nobreak\ndeposit %06o %012o\n" % (meta, pin0) +
        "echo V1898_TEST_ONLY_ZERO_TARGET_PIN\n" +
        "examine %06o\n" % meta +
        "echo V1898_END_TEST_ONLY_ZERO_TARGET_PIN\n" +
        "break %06o\ncont\n" % target_return +
        "echo V1898_ORIGINAL_FIRST_UNPIN_REFUSAL\nexamine 1\n" +
        snapshot("FIRST_UNPIN_REFUSED") +
        "nobreak\nbreak %06o\ncont\n" % retry_call +
        "echo V1898_ORIGINAL_CLEANUP_TARGET_UNPIN_CALL\n" +
        "examine %06o\n" % meta + snapshot("CLEANUP_UNPIN_CALL") +
        "nobreak\nbreak %06o\ncont\n" % retry_return +
        "echo V1898_ORIGINAL_SECOND_UNPIN_REFUSAL\nexamine 1\n" +
        snapshot("SECOND_UNPIN_REFUSED") +
        "nobreak\nbreak %06o\ncont\n" % expected["service_return"] +
        "echo V1898_ORIGINAL_FAILED_FULL_RETURN\nexamine 1\n" +
        snapshot("QUARANTINED") +
        "nobreak\nexpect \"HB\"\ncont\n" +
        "echo V1898_PARENT_USER_HEARTBEAT_1\n" +
        snapshot("HEARTBEAT_1") +
        "expect \"HB\"\ncont\n" +
        "echo V1898_PARENT_USER_HEARTBEAT_2\n" +
        snapshot("HEARTBEAT_2") +
        "exit\n")
    if result.count("deposit %06o %012o" % (meta, pin0)) != 1 or \
            result.count("deposit %06o %012o" % (meta, pin1)) or \
            result.count('expect "HB"\ncont\n') != 2 or \
            "detach dtc3" in result:
        raise ValueError("v1898 must only zero target pin ONCE, never restore")
    (work / "physical.ini").write_text(result, encoding="ascii")
    (work / "expected-v1898.txt").write_text(
        ("target_call %06o\ntarget_return %06o\n"
         "retry_call %06o\nretry_return %06o\n"
         "service_return %06o\ntarget_meta_address %06o\n"
         "target_meta_pin1 %012o\ntarget_meta_pin0 %012o\n"
         "process_table 044712\n") %
        (target_call, target_return, retry_call, retry_return,
         expected["service_return"], meta, pin1, pin0), encoding="ascii")
    print("v1898: original target unpin CALL=%06o RETURN=%06o" %
          (target_call, target_return))
    print("v1898: original fail_target retry CALL=%06o RETURN=%06o" %
          (retry_call, retry_return))
    print("v1898: only test mutation target MM word %06o: %012o -> %012o" %
          (meta, pin1, pin0))


if __name__ == "__main__":
    if len(sys.argv) != 8:
        raise SystemExit("usage: prepare-v1898.py kit build probe v1897work work dxrcheck objdump")
    prepare(*(Path(a) for a in sys.argv[1:]))
