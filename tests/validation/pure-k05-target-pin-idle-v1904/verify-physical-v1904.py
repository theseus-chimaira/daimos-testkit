#!/usr/bin/env python3
"""Verify original PDP-6 persistent target pin through live idle backoff."""

from pathlib import Path
import hashlib
import re
import runpy
import sys


def word(text, addr):
    words = re.findall(r"(?m)^%o:\s*([0-7]{12})\s*$" % addr,text)
    if not words or len(set(words)) != 1:
        raise ValueError("missing/ambiguous native word %06o" % addr)
    return int(words[0],8)


def section(trace, first, last):
    a, b = first+"\n",last+"\n"
    if trace.count(a) != 1 or trace.count(b) != 1:
        raise ValueError("missing original checkpoint: " + first)
    return trace.split(a,1)[1].split(b,1)[0]


def values(path):
    return dict((key,int(value,8)) for key,value in re.findall(
        r"(?m)^([a-z0-9_]+)\s+([0-7]+)\s*$",
        path.read_text(encoding="ascii")))


def verify(kit, build, work):
    if hashlib.sha256((build / "kcore.dxr").read_bytes()).hexdigest() != \
            "a201a7fdcf481b436b06694e5dd55c9367036ebd9f64c630486f854b1a4f89be" or \
            hashlib.sha256((build / "pure-mres-v1612.dxr").read_bytes()).hexdigest() != \
            "55be5113d4d15fe5c4a44409dca22afd463c75f05f661b3f8f71451a057c577f":
        raise ValueError("v1904 not unchanged accepted v1903 KCORE/PURE binaries")
    # Keep every strict v1903 end-to-end native-MM, saved context and
    # five original typed WAIT/HALT assertion, not just console output.
    prior = runpy.run_path(str(kit / "tests/validation/"
                        "pure-k05-full-commit-v1903/verify-physical-v1903.py"))
    prior["verify"](kit,build,work)
    base = runpy.run_path(str(kit / "tests/validation/"
                       "pure-k05-secondary-physical-v1845/prepare-v1845.py"))
    mm = runpy.run_path(str(kit / "tests/diagnostics/"
                     "pure-full-restore-v1638/audit-v1638.py"))
    core = base["symbols"](build / "kcore.map")
    expected = values(work / "expected-v1904.txt")
    old = values(work / "expected-v1903.txt")
    raw = values(work / "expected-v1902.txt")
    script = (work / "physical.ini").read_text(encoding="ascii")
    trace = (work / "physical.clean").read_text(encoding="ascii")
    target_meta = expected["target_meta"]
    if target_meta != raw["source_meta"]+2 or \
            target_meta != core["mm_extents"]+0o41 or \
            expected["target_pin0"] != 0o1000003 or \
            expected["target_pin1"] != 0o11000003 or \
            script.count("deposit %06o %012o\n" %
                         (target_meta,expected["target_pin1"])) != 1 or \
            script.count("deposit %06o %012o\n" %
                         (target_meta,expected["target_pin0"])) != 1:
        raise ValueError("wrong physical target descriptor/pin protocol")
    stages = (
        "V1902_END_PIN_RELEASE", "V1904_TARGET_EXTERNAL_PIN_INSTALL",
        "V1904_END_TARGET_PIN_INSTALL",
        "V1904_TARGET_PINNED_PARENT_HB_1", "V1904_END_HELD_HB_1",
        "V1904_TARGET_PINNED_PARENT_HB_2", "V1904_END_HELD_HB_2",
        "V1904_TARGET_PINNED_PARENT_HB_3", "V1904_END_HELD_HB_3",
        "V1904_TARGET_EXTERNAL_PIN_RELEASE", "V1904_END_TARGET_PIN_RELEASE",
        "V1903_ORIGINAL_NATIVE_TARGET_FREE_CALL",
        "V1903_ORIGINAL_NATIVE_TARGET_FREE_RETURN",
        "V1903_SECOND_NATIVE_SOURCE_FREE_RETURN",
        "V1903_ORIGINAL_PARENT_TYPED_WAIT_Z", "V1903_ORIGINAL_NATIVE_HALT")
    markers = [x+"\n" for x in stages]
    if any(trace.count(x)!=1 for x in markers) or \
            [trace.index(x) for x in markers] != sorted(trace.index(x) for x in markers):
        raise ValueError("persistent target-pin/HB/release stages reordered")
    if word(section(trace,"V1904_TARGET_EXTERNAL_PIN_INSTALL",
                    "V1904_END_TARGET_PIN_INSTALL"),target_meta) != \
            expected["target_pin0"] or \
            word(section(trace,"V1904_TARGET_EXTERNAL_PIN_RELEASE",
                    "V1904_END_TARGET_PIN_RELEASE"),target_meta) != \
            expected["target_pin1"]:
        raise ValueError("test-only physical pin install/release preflight invalid")

    held = []
    for i in (1,2,3):
        label = "HELD_HB_%d" % i
        block,ext = mm["stage"](trace.replace("V1904_","V1638_"),
                                 core,label)
        src = section(trace,"V1904_STAGE_"+label,"V1904_END_"+label)
        held.append((block,ext,src))

    original, owners = mm["stage"](trace.replace("V1902_","V1638_"),
                                   core,"PINNED_HB")
    packed1 = (0o111200,0o120000,4,1,3)
    packed0 = (0o111200,0o120000,4,0,3)
    target0 = (0o120000,0o130000,1,0,3)
    target1 = (0o120000,0o130000,1,1,3)
    if owners.count(packed1) != 1 or owners.count(target0) != 1:
        raise ValueError("original source-free refusal owners not exact")
    expected_held = [packed0 if x == packed1 else
                     target1 if x == target0 else x for x in owners]
    root = original[core["vfs_namespace_root"]]
    saved = None
    clocks = []
    intervals = []
    for i,(block,ext,src) in enumerate(held,1):
        if ext != expected_held or block[core["mm_extent_count"]] != 18 or \
                block[core["proc_current_slot"]] != 1 or \
                block[core["vfs_namespace_root"]] != root or \
                word(src,core["proc_table"]) != old["process_table"] or \
                word(src,old["process_table"]+9) >> 18 != old["uarea"] or \
                not (word(src,old["process_table"]+9) & (1<<16)) or \
                (word(src,old["process_table"]+10) & 0o777777) or \
                word(src,old["parent_gate"]) != 0:
            raise ValueError("pinned slot3 MM/TRANSITION/VM/ROOT changed at HB%d"%i)
        # An actual denied slot-0 retry must remain pending, not lose
        # its one shared timer and silently strand the blocked owner.
        # This word is immediately after proc_timer_next in original
        # KCORE BSS; it is NOT a new test-only kernel variable.
        timer = word(src,expected["retry_word"])
        interval = (timer >> 18) & 0o377777
        if not (timer & (1 << 35)) or \
                interval == 0 or interval > 0o1000 or \
                (interval & (interval - 1)):
            raise ValueError("original failed-retry timer not safely pending")
        intervals.append(interval)
        ctx = (word(src,old["uarea"]+0o20),
               word(src,old["uarea"]+0o24),
               word(src,old["uarea"]+0o67))
        if saved is None:
            saved = ctx
            if (ctx[0] >> 18) & 0o10000 or ctx[2] != (1 << 32):
                raise ValueError("held owner lost executive context/retry tag")
        if ctx != saved:
            raise ValueError("persistent pin changed saved private continuation")
        clocks.append(word(src,core["proc_timer_clock"]))
    if not clocks[0] < clocks[1] < clocks[2]:
        raise ValueError("original resident parent/PCLK failed under pinned retry")
    if not intervals[0] < intervals[1] <= intervals[2]:
        raise ValueError("original shared retry backoff did not advance")
    released = section(trace,"V1904_TARGET_EXTERNAL_PIN_RELEASE",
                       "V1904_END_TARGET_PIN_RELEASE")
    release_clock = word(released,core["proc_timer_clock"])
    if release_clock < clocks[2]:
        raise ValueError("target pin released before original third heartbeat")
    before_free = section(trace,"V1903_STAGE_BEFORE_TARGET_FREE",
                          "V1903_END_BEFORE_TARGET_FREE")
    free_clock = word(before_free,core["proc_timer_clock"])
    delay = (free_clock - release_clock) & 0o377777
    if delay <= 0:
        raise ValueError("target MM free did not follow external pin release")
    # The original v1903 auditor establishes actual native target free,
    # new FULL commit and all five typed WAITs after the external pin
    # is released. Reaching this assertion is NOT a merely idle guest.
    print("PASS v1904: original pinned target retains exact MM18/TRANSITION")
    print("PASS v1904: three real parent HBs, advancing PCLK and saved CTX")
    print("v1904: original retry intervals %04o -> %04o -> %04o octal ticks" %
          tuple(intervals))
    print("v1904: original target-free after pin release: %06o octal PCLK ticks" % delay)
    print("PASS v1904: pin release allows native target free and FULL/WAIT/HALT")


if __name__ == "__main__":
    if len(sys.argv) != 4:
        raise SystemExit("usage: verify-physical-v1904.py kit source-build physical-work")
    try:
        verify(*(Path(x) for x in sys.argv[1:]))
    except (OSError,ValueError,KeyError,AssertionError,UnicodeError) as exc:
        raise SystemExit("FAIL v1904 real PDP6 persistent-pin test: " + str(exc))
