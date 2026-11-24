#!/usr/bin/env python3
"""Verify native two-owner recovery, second FULL commit and typed WAIT."""

from pathlib import Path
import re
import runpy
import sys


def section(trace, start, end):
    a, b = start + "\n", end + "\n"
    if trace.count(a) != 1 or trace.count(b) != 1:
        raise ValueError("original physical checkpoint missing: " + start)
    return trace.split(a, 1)[1].split(b, 1)[0]


def word(text, address):
    matches = re.findall(r"(?m)^%o:\s*([0-7]{12})\s*$" % address, text)
    if not matches or len(set(matches)) != 1:
        raise ValueError("absent/ambiguous original PDP-6 word %06o" % address)
    return int(matches[0], 8)


def values(path):
    return dict((a, int(b, 8)) for a, b in re.findall(
        r"(?m)^([a-z0-9_]+)\s+([0-7]+)\s*$",
        path.read_text(encoding="ascii")))


def verify(kit, build, work):
    base = runpy.run_path(str(kit / "tests/validation/"
                       "pure-k05-secondary-physical-v1845/prepare-v1845.py"))
    mm = runpy.run_path(str(kit / "tests/diagnostics/"
                     "pure-full-restore-v1638/audit-v1638.py"))
    core = base["symbols"](build / "kcore.map")
    expected = values(work / "expected-v1903.txt")
    first = values(work / "expected-v1902.txt")
    trace = (work / "physical.clean").read_text(encoding="ascii")
    script = (work / "physical.ini").read_text(encoding="ascii")
    source = (build.parent / "user/init-v1614.c").read_text(encoding="ascii")
    user_map = base["symbols"](build.parent / "user/init.map")
    table = expected["process_table"]
    uarea = expected["uarea"]
    gate = expected["parent_gate"]
    source_meta = first["source_meta"]

    if source.count("if (v1901_term_gate != 0UL)") != 1 or \
            source.count("SYS_WAIT_STATUS_KIND(status)") != 1 or \
            gate != expected["parent_apr"] + user_map["v1901_term_gate"]:
        raise ValueError("original test-only parent USER WAIT gate drifted")
    if expected["parent_apr"] != 0o130000 or \
            source_meta != core["mm_extents"] + 0o37 or \
            "nobreak\n" in script or \
            script.count("deposit %06o %012o\n" %
                         (gate, 0o12345670123)) != 1 or \
            script.count("deposit %06o %012o\n" %
                         (source_meta, first["source_pin1"])) != 1 or \
            script.count("deposit %06o %012o\n" %
                         (source_meta, first["source_pin0"])) != 1:
        raise ValueError("test injection escaped exactly one source pin + USER gate")
    if not all(x in trace for x in (
            "MEM                                  48 K",
            "PURE                              LOADED",
            "DTFS                              LOADED", "aaaaax[B")) or \
            "detach dtc3" in trace:
        raise ValueError("not a real source-linked 48K PDP-6 five-child guest")
    events = (
        "V1845_END_FULL_PINNED", "V1902_NATIVE_SOURCE_FREE_CALL",
        "V1902_REAL_MM_FREE_REFUSED", "V1902_ORIGINAL_FAILED_FULL_RETURN",
        "V1902_REAL_PARENT_HEARTBEAT_PINNED", "V1902_EXTERNAL_PIN_RELEASE",
        "V1903_ORIGINAL_NATIVE_TARGET_FREE_CALL",
        "V1903_ORIGINAL_NATIVE_TARGET_FREE_RETURN",
        "V1903_ORIGINAL_SLOT0_TRANSITION_CLEAR",
        "V1903_ORIGINAL_PARENT_AFTER_RECOVERY",
        "V1903_SECOND_NATIVE_SOURCE_FREE_RETURN",
        "V1903_SECOND_FULL_SERVICE_RETURN",
        "V1903_TEST_ONLY_PARENT_USER_GATE", "V1903_END_PARENT_USER_GATE",
        "V1903_ORIGINAL_PARENT_TYPED_WAIT_Z", "V1903_ORIGINAL_NATIVE_HALT")
    markers = [x + "\n" for x in events]
    if any(trace.count(x) != 1 for x in markers) or \
            [trace.index(x) for x in markers] != sorted(trace.index(x) for x in markers):
        raise ValueError("actual native MM/parent WAIT stages absent or reordered")
    for key in ("source_return", "service_return", "native_target_call",
                "transition_clear"):
        if not re.search(r"Breakpoint, PC: %06o " % expected[key], trace):
            raise ValueError("source-linked original native PC never executed: " + key)
    if word(section(trace,"V1902_REAL_MM_FREE_REFUSED",
                    "V1902_STAGE_NATIVE_REFUSED"),1) != 0o777777777773:
        raise ValueError("initial original PACKED MM free did not refuse -5")
    if word(section(trace,"V1903_ORIGINAL_NATIVE_TARGET_FREE_RETURN",
                    "V1903_STAGE_TARGET_FREED"),1) != 0:
        raise ValueError("idle original target free did not complete")
    if word(section(trace,"V1903_SECOND_NATIVE_SOURCE_FREE_RETURN",
                    "V1903_STAGE_SOURCE_FREED"),1) != 0:
        raise ValueError("second original PACKED free did not complete")

    def capture(prefix, label):
        scalar, extent = mm["stage"](
            trace.replace(prefix+"_", "V1638_"), core, label)
        context = section(trace, prefix+"_STAGE_"+label,
                          prefix+"_END_"+label)
        return scalar, extent, context

    initial, initial_ext, _ = capture("V1845", "FULL_PINNED")
    refused, refused_ext, _ = capture("V1902", "NATIVE_REFUSED")
    held, held_ext, held_text = capture("V1902", "PINNED_HB")
    before, before_ext, before_text = capture("V1903", "BEFORE_TARGET_FREE")
    freed, freed_ext, freed_text = capture("V1903", "TARGET_FREED")
    unlocked, unlocked_ext, unlocked_text = capture("V1903", "TRANSITION_UNLOCKED")
    parent, parent_ext, parent_text = capture("V1903", "PARENT_AFTER_RECOVERY")
    source, source_ext, source_text = capture("V1903", "SOURCE_FREED")
    committed, committed_ext, committed_text = capture("V1903", "FULL_COMMITTED")
    final, final_ext, final_text = capture("V1903", "PARENT_Z")
    halt, halt_ext, halt_text = capture("V1903", "HALT")

    packed1 = (0o111200,0o120000,4,1,3)
    packed0 = (0o111200,0o120000,4,0,3)
    target1 = (0o120000,0o130000,1,1,3)
    target0 = (0o120000,0o130000,1,0,3)
    if initial_ext.count(packed1) != 1 or initial_ext.count(target1) != 1:
        raise ValueError("original FULL did not pin exact RAW+target owner pair")
    normal = [target0 if x == target1 else x for x in initial_ext]
    after_pin = [packed0 if x == packed1 else x for x in normal]
    cleaned = [x for x in after_pin if x != target0]
    next_target = after_pin
    restored = [x for x in next_target if x != packed0]
    for name,scalars,extents,want,n in (
            ("initial",initial,initial_ext,initial_ext,18),
            ("refused",refused,refused_ext,normal,18),
            ("held",held,held_ext,normal,18),
            ("before target",before,before_ext,after_pin,18),
            ("target freed",freed,freed_ext,cleaned,17),
            ("transition unlocked",unlocked,unlocked_ext,cleaned,17),
            ("parent after recovery",parent,parent_ext,cleaned,17),
            ("source freed",source,source_ext,restored,17),
            ("FULL committed",committed,committed_ext,restored,17)):
        if extents != want or scalars[core["mm_extent_count"]] != n or \
                scalars[core["vfs_namespace_root"]] != \
                initial[core["vfs_namespace_root"]]:
            raise ValueError("original MM owners/ROOT not exact: " + name)
    # A new FULL obtains a fresh provisional target before its second
    # source-free call. Its extent shape matches the first target0.
    # The second source-free snapshot must retain only that target.
    # Assert exact original parent and saved private executive context
    # before making the private user gate runnable.
    # The reused v1902 heartbeat snapshots record MM ownership but not
    # the dynamically relocated process-table and private u-area range.
    # The first complete context witness is the native target-free call.
    snapshot_texts = (before_text,freed_text,unlocked_text,
                      parent_text,source_text,committed_text)
    if any(word(t,core["proc_table"]) != table or
           (word(t,table+3) >> 18) == 0 for t in snapshot_texts):
        raise ValueError("original runtime process table or parent disappeared")
    context_pc = word(before_text,uarea+0o20)
    fdctl = word(before_text,uarea+0o24)
    if (context_pc >> 18) & 0o10000:
        raise ValueError("child did not retain an executive continuation")
    for t in (before_text,freed_text,unlocked_text,parent_text):
        if word(t,uarea+0o20) != context_pc or \
                word(t,uarea+0o24) != fdctl or \
                word(t,table+9) >> 18 != uarea:
            raise ValueError("slot3 private kernel continuation corrupted")
    if word(freed_text,table+9) & (1<<16) == 0 or \
            word(unlocked_text,table+9) & (1<<16) != 0 or \
            word(unlocked_text,uarea+0o67) != 0:
        raise ValueError("slot-0 native target removal did not safely unlock")
    if word(source_text,table+9) & (1<<16) == 0 or \
            word(committed_text,table+9) & (1<<16) != 0 or \
            (word(source_text,table+10) & 0o777777) != 0 or \
            (word(committed_text,table+10) & 0o777777) != 0o120000:
        raise ValueError("second FULL did not publish original RESIDENT APR")
    for t in (before_text,freed_text,unlocked_text,parent_text,
              source_text,committed_text):
        if word(t,gate) != 0:
            raise ValueError("parent gate opened before real native FULL commit")
    gate_read = section(trace,"V1903_TEST_ONLY_PARENT_USER_GATE",
                        "V1903_END_PARENT_USER_GATE")
    if word(gate_read,gate) != 0:
        raise ValueError("parent USER gate unexpectedly preset")
    if not any(a == 0o130000 and b == 0o140000 and kind == 1 and
               pin == 0 and owner == 1 for a,b,kind,pin,owner in committed_ext):
        raise ValueError("user gate was not in original resident parent APR")
    if any(owner == 3 and kind in (1,4) for a,b,kind,pin,owner in final_ext):
        raise ValueError("original typed WAIT did not release restored slot3")
    if any(owner == 3 and kind in (1,4) for a,b,kind,pin,owner in halt_ext):
        raise ValueError("original HALT leaked slot3 MM")
    if final[core["vfs_namespace_root"]] != initial[core["vfs_namespace_root"]] or \
            halt[core["vfs_namespace_root"]] != initial[core["vfs_namespace_root"]]:
        raise ValueError("ROOT changed during original child/parent exit")
    progress = section(trace,"V1845_END_A","V1903_ORIGINAL_PARENT_TYPED_WAIT_Z")
    if progress.count("w") != 5 or not progress.endswith("Z") or \
            "!" in progress or "HALT instruction, PC: 000000" not in trace:
        raise ValueError("five original child EXIT/typed WAIT or HALT incomplete")
    print("PASS v1903: real -5 source free, held pin, true idle target free 0")
    print("PASS v1903: exact MM rollback and second source free 0")
    print("PASS v1903: original FULL RESIDENT 120000/TRANSITION clear")
    print("PASS v1903: original five typed EXIT/WAIT, parent Z and real HALT")


if __name__ == "__main__":
    if len(sys.argv) != 4:
        raise SystemExit("usage: verify-physical-v1903.py kit build physical-work")
    try:
        verify(*(Path(s) for s in sys.argv[1:]))
    except (OSError,ValueError,KeyError,AssertionError,UnicodeError) as exc:
        raise SystemExit("FAIL v1903 original PDP6 physical: " + str(exc))
