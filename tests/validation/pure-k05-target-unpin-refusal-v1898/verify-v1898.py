#!/usr/bin/env python3
"""Independent original PDP6 two native target mm_unpin -4 audit."""

from pathlib import Path
import hashlib
import re
import runpy
import sys


def section(text, start, stop):
    a = "V1898_%s\n" % start
    b = "V1898_%s\n" % stop
    if text.count(a) != 1 or text.count(b) != 1:
        raise ValueError("original unpin physical checkpoint absent: " + start)
    return text.split(a, 1)[1].split(b, 1)[0]


def read_word(text, addr):
    matches = re.findall(r"(?m)^%o:\s*([0-7]{12})\s*$" % addr, text)
    if len(matches) != 1:
        raise ValueError("original physical address not uniquely observed %06o" % addr)
    return int(matches[0], 8)


def read(kit, build, work):
    a = runpy.run_path(str(kit / "tests/diagnostics/"
                    "pure-full-restore-v1638/audit-v1638.py"))
    core = a["symbols"]((build / "kcore.map").read_text(encoding="ascii"))
    trace = (work / "physical.clean").read_text(encoding="ascii")
    exp = dict((n, int(v, 8)) for n, v in re.findall(
        r"(?m)^([a-z0-9_]+)\s+([0-7]+)\s*$",
        (work / "expected-v1898.txt").read_text(encoding="ascii")))
    if hashlib.sha256((build / "kcore.dxr").read_bytes()).hexdigest() != \
            "33bf700218a73fefcb36ebb1f1d835c1817f3a291a642898ccb3cbd5d9039d8b" or \
            hashlib.sha256((build / "pure-mres-v1612.dxr").read_bytes()).hexdigest() != \
            "a0fb25c51cf1c57f4bc70ca1dc83d8b9ea39b1ac3ddb3bba7b9ffcea17e5b3fd":
        raise ValueError("not unchanged accepted v1855 original KCORE and PURE")
    source = (build.parent / "user/init-v1614.c").read_text(encoding="ascii")
    for marker in ("(void)p14_char('H');", "(void)p14_char('B');",
                   "#define P14_CHILDREN         5U"):
        if source.count(marker) != 1:
            raise ValueError("not original five children plus resident parent HB fixture")
    if source.index("(void)p14_char('L');") >= source.index(
            "(void)p14_char('H');"):
        raise ValueError("original parent marker not after child pressure")
    marks = ["V1845_STAGE_FULL_PINNED\n", "V1845_END_FULL_PINNED\n",
        "V1898_ORIGINAL_TARGET_UNPIN_CALL\n",
        "V1898_STAGE_BEFORE_TARGET_UNPIN\n", "V1898_END_BEFORE_TARGET_UNPIN\n",
        "V1898_TEST_ONLY_ZERO_TARGET_PIN\n", "V1898_END_TEST_ONLY_ZERO_TARGET_PIN\n",
        "V1898_ORIGINAL_FIRST_UNPIN_REFUSAL\n",
        "V1898_STAGE_FIRST_UNPIN_REFUSED\n", "V1898_END_FIRST_UNPIN_REFUSED\n",
        "V1898_ORIGINAL_CLEANUP_TARGET_UNPIN_CALL\n",
        "V1898_STAGE_CLEANUP_UNPIN_CALL\n", "V1898_END_CLEANUP_UNPIN_CALL\n",
        "V1898_ORIGINAL_SECOND_UNPIN_REFUSAL\n",
        "V1898_STAGE_SECOND_UNPIN_REFUSED\n", "V1898_END_SECOND_UNPIN_REFUSED\n",
        "V1898_ORIGINAL_FAILED_FULL_RETURN\n",
        "V1898_STAGE_QUARANTINED\n", "V1898_END_QUARANTINED\n",
        "V1898_PARENT_USER_HEARTBEAT_1\n",
        "V1898_STAGE_HEARTBEAT_1\n", "V1898_END_HEARTBEAT_1\n",
        "V1898_PARENT_USER_HEARTBEAT_2\n",
        "V1898_STAGE_HEARTBEAT_2\n", "V1898_END_HEARTBEAT_2\n"]
    if any(trace.count(x) != 1 for x in marks) or \
            [trace.index(x) for x in marks] != sorted(trace.index(x) for x in marks):
        raise ValueError("original MM unpin call/refusal/HB stage order invalid")
    for token in ("MEM                                  48 K",
                  "PURE                              LOADED",
                  "DTFS                              LOADED", "aaaaax[B"):
        if token not in trace:
            raise ValueError("not original PDP6 48K five-child pressure")
    if "detach dtc3" in trace or "V1845_DTC3_DETACHED" in trace:
        raise ValueError("original physical secondary executable backing detached")
    for name in ("target_call", "target_return", "retry_call",
                 "retry_return", "service_return"):
        if not re.search(r"Breakpoint, PC: %06o " % exp[name], trace):
            raise ValueError("original compiled native mm_unpin PC absent: " + name)
    first, original = a["stage"](
        trace.replace("V1845_", "V1638_"), core, "FULL_PINNED")
    src = (0o111200, 0o120000, 4, 1, 3)
    target1 = (0o120000, 0o130000, 1, 1, 3)
    target0 = (0o120000, 0o130000, 1, 0, 3)
    if original.count(src) != 1 or original.count(target1) != 1 or \
            first[core["mm_extent_count"]] != 18:
        raise ValueError("original FULL pinned pair missing or wrong geometry")
    zero_target = [target0 if x == target1 else x for x in original]
    root = first[core["vfs_namespace_root"]]
    frame, owners = a["stage"](
        trace.replace("V1898_", "V1638_"), core, "BEFORE_TARGET_UNPIN")
    meta = exp["target_meta_address"]
    if owners != original or frame[core["mm_extent_count"]] != 18:
        raise ValueError("native target unpin did not start with both exact one-pin owners")
    if read_word(section(trace, "ORIGINAL_TARGET_UNPIN_CALL", "STAGE_BEFORE_TARGET_UNPIN"),
                 meta) != exp["target_meta_pin1"]:
        raise ValueError("original target did not have one pin at native unpin call")
    if read_word(section(trace, "TEST_ONLY_ZERO_TARGET_PIN", "END_TEST_ONLY_ZERO_TARGET_PIN"),
                 meta) != exp["target_meta_pin0"]:
        raise ValueError("external test-only zero target pin not actually injected")

    for tag, left, expected_return in (
        ("FIRST_UNPIN_REFUSED", "ORIGINAL_FIRST_UNPIN_REFUSAL", 0o777777777774),
        ("SECOND_UNPIN_REFUSED", "ORIGINAL_SECOND_UNPIN_REFUSAL", 0o777777777774)):
        if read_word(section(trace, left, "STAGE_" + tag), 1) != expected_return:
            raise ValueError("original native %s did not return genuine MM_ERR_INVAL -4" % tag)

    for tag in ("FIRST_UNPIN_REFUSED", "CLEANUP_UNPIN_CALL",
                "SECOND_UNPIN_REFUSED", "QUARANTINED", "HEARTBEAT_1",
                "HEARTBEAT_2"):
        frame, owners = a["stage"](
            trace.replace("V1898_", "V1638_"), core, tag)
        block = section(trace, "STAGE_" + tag, "END_" + tag)
        if owners != zero_target or frame[core["mm_extent_count"]] != 18:
            raise ValueError("original double native unpin refusal changed owners: " + tag)
        if frame[core["vfs_namespace_root"]] != root:
            raise ValueError("original selected TSFS root changed during double unpin refusal")
        if read_word(block, core["proc_table"]) != exp["process_table"]:
            raise ValueError("original process-table pointer changed")
        meta3 = read_word(block, exp["process_table"] + 9)
        vm3 = read_word(block, exp["process_table"] + 10)
        if not (meta3 & (1 << 16)) or (vm3 & 0o777777):
            raise ValueError("unsafe original slot3 TRANSITION or VM0 after unpin refusal")
        if tag == "CLEANUP_UNPIN_CALL":
            if read_word(section(trace, "ORIGINAL_CLEANUP_TARGET_UNPIN_CALL",
                                 "STAGE_CLEANUP_UNPIN_CALL"), meta) != \
                    exp["target_meta_pin0"]:
                raise ValueError("original cleanup did not retry already-zero target pin")
        if tag == "QUARANTINED":
            if read_word(section(trace, "ORIGINAL_FAILED_FULL_RETURN",
                                 "STAGE_QUARANTINED"), 1) != 0o777777777773:
                raise ValueError("original FULL did not report BUSY after two real -4")
        if tag in ("HEARTBEAT_1", "HEARTBEAT_2"):
            if frame[core["proc_current_slot"]] != 1:
                raise ValueError("original user HB was not resident parent slot1")
            parent_meta = read_word(block, exp["process_table"] + 3)
            parent_vm = read_word(block, exp["process_table"] + 4)
            parent_sched = read_word(block, exp["process_table"] + 5)
            if parent_meta & (1 << 16) or \
                    (parent_vm & 0o777777) != 0o130000 or \
                    (parent_sched >> 33 & 7) != 2 or \
                    (0o130000, 0o140000, 1, 0, 1) not in owners:
                raise ValueError("original parent lost independent valid resident APR")
    b1 = section(trace, "STAGE_HEARTBEAT_1", "END_HEARTBEAT_1")
    b2 = section(trace, "STAGE_HEARTBEAT_2", "END_HEARTBEAT_2")
    if read_word(b2, core["proc_timer_clock"]) <= \
            read_word(b1, core["proc_timer_clock"]):
        raise ValueError("original PCLK did not advance between two genuine HBs")
    for event, prev in (("PARENT_USER_HEARTBEAT_1", "V1898_END_QUARANTINED\n"),
                       ("PARENT_USER_HEARTBEAT_2", "V1898_END_HEARTBEAT_1\n")):
        window = trace.split(prev, 1)[1].split("V1898_" + event + "\n", 1)[0]
        if not re.search(r"HB\s*$", window):
            raise ValueError("original parent did not emit two real user heartbeats")
    print("PASS v1898: both original mm_unpin(PROCESS target) calls returned genuine -4")
    print("v1898: source pin1 and target pin0 retained, 18 identical MM owners")
    print("v1898: original FULL BUSY/quarantine VM0, two autonomous parent HBs with PCLK")
    print("NOT PROVEN: a naturally occurring PI-atomic zero-pin race or terminal cleanup")


if __name__ == "__main__":
    if len(sys.argv) != 4:
        raise SystemExit("usage: verify-v1898.py kit original-build physical-work")
    try:
        read(*(Path(s) for s in sys.argv[1:]))
    except (ValueError, KeyError, OSError, AssertionError, UnicodeError) as exc:
        raise SystemExit("FAIL v1898 original PDP6 target-unpin physical: " + str(exc))
