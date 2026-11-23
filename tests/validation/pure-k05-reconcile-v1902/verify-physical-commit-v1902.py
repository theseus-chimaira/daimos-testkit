#!/usr/bin/env python3
"""Read-only original PDP-6 KCORE idle recovery/native target MM free."""

from pathlib import Path
import hashlib
import re
import runpy
import sys


def stage_text(t, prefix, label):
    a = "%s_STAGE_%s\n" % (prefix, label)
    b = "%s_END_%s\n" % (prefix, label)
    if t.count(a) != 1 or t.count(b) != 1:
        raise ValueError("original physical checkpoint not unique: " + label)
    return t.split(a, 1)[1].split(b, 1)[0]


def word(text, address):
    values = re.findall(r"(?m)^%o:\s*([0-7]{12})\s*$" % address, text)
    # Original v1845 snapshots may examine the same physical scalar
    # twice (once explicitly, once in a canonical MM/ROOT range).
    # Both readings must agree; equal duplicate observations are safe.
    if not values or len(set(values)) != 1:
        raise ValueError("actual PDP6 word absent or ambiguous: %06o" % address)
    return int(values[0], 8)


def event_word(t, a, b, address):
    start, end = a + "\n", b + "\n"
    if t.count(start) != 1 or t.count(end) != 1:
        raise ValueError("original PDP6 event boundaries not unique")
    return word(t.split(start, 1)[1].split(end, 1)[0], address)


def read(kit, build, work):
    trace = (work / "physical.clean").read_text(encoding="ascii")
    core_sha = "aa80ea2d98778298c13ae96de76c52815cfd40ad5486030e5056b436f85072f5"
    pure_sha = "2dd7b7f7340d5b1b9542a97d0e8aca8478ac32afc3c555f0ae1ab38d0cd39a6b"
    if hashlib.sha256((build / "kcore.dxr").read_bytes()).hexdigest() != core_sha or \
            hashlib.sha256((build / "pure-mres-v1612.dxr").read_bytes()).hexdigest() != pure_sha:
        raise ValueError("v1902 real PDP6 not exact linked KCORE/PURE recovery")
    base = runpy.run_path(str(kit / "tests/validation/"
                       "pure-k05-secondary-physical-v1845/prepare-v1845.py"))
    mm = runpy.run_path(str(kit / "tests/diagnostics/"
                     "pure-full-restore-v1638/audit-v1638.py"))
    core = base["symbols"](build / "kcore.map")
    exp = dict((key,int(value,8)) for key,value in re.findall(
        r"(?m)^([a-z0-9_]+)\s+([0-7]+)\s*$",
        (work/"expected-v1902.txt").read_text(encoding="ascii")))
    ext = dict((key,int(value,8)) for key,value in re.findall(
        r"(?m)^([a-z0-9_]+)\s+([0-7]+)\s*$",
        (work/"expected-v1902-commit.txt").read_text(encoding="ascii")))
    if exp["source_meta"] != core["mm_extents"] + 0o37 or \
            exp["source_pin1"] != 0o14000003 or \
            exp["source_pin0"] != 0o4000003 or \
            ext["process_table"] != 0o45516 or ext["uarea"] != 0o46635:
        raise ValueError("original physical RAW/target/MM process geometry drifted")
    if not all(trace.count(m) == 1 for m in (
            "V1845_STAGE_FULL_PINNED\n", "V1845_END_FULL_PINNED\n",
            "V1902_NATIVE_SOURCE_FREE_CALL\n",
            "V1902_TEST_ONLY_PIN\n",
            "V1902_REAL_MM_FREE_REFUSED\n",
            "V1902_ORIGINAL_FAILED_FULL_RETURN\n",
            "V1902_REAL_PARENT_HEARTBEAT_PINNED\n",
            "V1902_EXTERNAL_PIN_RELEASE\n",
            "V1902REC_ORIGINAL_NATIVE_PROCESS_FREE_CALL\n",
            "V1902REC_ORIGINAL_NATIVE_PROCESS_FREE_RETURN\n",
            "V1902REC_ORIGINAL_SLOT0_TRANSITION_CLEAR\n",
            "V1902REC_ORIGINAL_PARENT_USER_AFTER_RECOVERY\n")):
        raise ValueError("original PDP6 exact stage marker missing or repeated")
    order = ["V1845_END_FULL_PINNED\n", "V1902_NATIVE_SOURCE_FREE_CALL\n",
             "V1902_TEST_ONLY_PIN\n", "V1902_REAL_MM_FREE_REFUSED\n",
             "V1902_ORIGINAL_FAILED_FULL_RETURN\n",
             "V1902_REAL_PARENT_HEARTBEAT_PINNED\n",
             "V1902_EXTERNAL_PIN_RELEASE\n",
             "V1902REC_ORIGINAL_NATIVE_PROCESS_FREE_CALL\n",
             "V1902REC_ORIGINAL_NATIVE_PROCESS_FREE_RETURN\n",
             "V1902REC_ORIGINAL_SLOT0_TRANSITION_CLEAR\n",
             "V1902REC_ORIGINAL_PARENT_USER_AFTER_RECOVERY\n"]
    if [trace.index(m) for m in order] != sorted(trace.index(m) for m in order):
        raise ValueError("original MM native / idle / HB ordering not chronological")
    for marker in ("MEM                                  48 K",
                   "PURE                              LOADED",
                   "DTFS                              LOADED", "aaaaax[B"):
        if marker not in trace:
            raise ValueError("v1902 not genuine five-child source 48K PDP6 boot")
    if "detach dtc3" in trace or "V1845_DTC3_DETACHED" in trace:
        raise ValueError("source-linked compressed executable backing detached")
    for name in ("source_call", "source_return", "service_return"):
        if not re.search(r"Breakpoint, PC: %06o " % exp[name], trace):
            raise ValueError("original PDP6 source-native PC not executed: " + name)
    for name in ("target_call", "target_return", "transition_clear"):
        if not re.search(r"Breakpoint, PC: %06o " % ext[name], trace):
            raise ValueError("original PDP6 source-linked recovery PC not executed: " + name)
    def snapshot(prefix, label):
        return mm["stage"](trace.replace(prefix+"_", "V1638_"), core, label)
    early, initial = snapshot("V1845", "FULL_PINNED")
    packed1 = (0o111200,0o120000,4,1,3)
    packed0 = (0o111200,0o120000,4,0,3)
    target1 = (0o120000,0o130000,1,1,3)
    target0 = (0o120000,0o130000,1,0,3)
    if early[core["mm_extent_count"]] != 18 or \
            initial.count(packed1) != 1 or initial.count(target1) != 1:
        raise ValueError("original source+target pinned owner pair not exact")
    refused_expected = [target0 if x == target1 else x for x in initial]
    released_expected = [packed0 if x == packed1 else x for x in refused_expected]
    cleaned_expected = [x for x in released_expected if x != target0]
    root = early[core["vfs_namespace_root"]]
    for label,expected_owners,n in (("NATIVE_REFUSED",refused_expected,18),
                                   ("FAILED_FULL",refused_expected,18),
                                   ("PINNED_HB",refused_expected,18)):
        fr, owners = snapshot("V1902",label)
        if owners != expected_owners or fr[core["mm_extent_count"]] != n:
            raise ValueError("original real source -5 changed owners: " + label)
    if event_word(trace,"V1902_TEST_ONLY_PIN",
                  "V1902_END_TEST_ONLY_PIN",exp["source_meta"]) != exp["source_pin1"]:
        raise ValueError("original source external pin not really held")
    if event_word(trace,"V1902_REAL_MM_FREE_REFUSED",
                  "V1902_STAGE_NATIVE_REFUSED",1) != 0o777777777773:
        raise ValueError("original fixed KCORE native source mm_free did not return -5")
    table = ext["process_table"]
    uarea = ext["uarea"]
    context = None
    fdctl = None
    for prefix,label,owners,n,transition in (
        ("V1902","FAILED_FULL",refused_expected,18,True),
        ("V1902","PINNED_HB",refused_expected,18,True),
        ("V1902REC","BEFORE_TARGET_FREE",released_expected,18,True),
        ("V1902REC","TARGET_FREED",cleaned_expected,17,True),
        ("V1902REC","TRANSITION_UNLOCKED",cleaned_expected,17,False)):
        fr, actual = snapshot(prefix,label)
        section = stage_text(trace,prefix,label)
        if fr[core["mm_extent_count"]] != n or actual != owners:
            raise ValueError("real native recovery MM ownership mismatch: " + label)
        if fr[core["vfs_namespace_root"]] != root or \
                word(section,core["proc_table"]) != table or \
                word(section,table+9) >> 18 != uarea or \
                bool(word(section,table+9) & (1<<16)) != transition or \
                word(section,table+10) & 0o777777:
            raise ValueError("original process slot3/ROOT/TRANSITION invalid: " + label)
        saved_pc = word(section,uarea+0o20)
        saved_fdctl = word(section,uarea+0o24)
        finalizer = word(section,uarea+0o67)
        if context is None:
            context,fdctl = saved_pc,saved_fdctl
            if (saved_pc >> 18) & 0o10000:
                raise ValueError("original saved CPU continuation unexpectedly USER")
        if saved_pc != context or saved_fdctl != fdctl:
            raise ValueError("native rollback changed private continuation: " + label)
        if transition:
            # FULL service returns before the slot-0 PURE caller arms
            # deferred retry. The original physical first HB proves
            # the retry is subsequently armed. Do not claim a marker
            # existed at an earlier original service-return PC.
            expected_tag = 0 if label == "FAILED_FULL" else (1<<32)
            if finalizer != expected_tag:
                raise ValueError("original deferred owner retry timing or FINALIZE invalid: " + label)
        elif finalizer != 0:
            raise ValueError("original recovery cleared TRANSITION but kept retry/FINALIZE")
    released = trace.split("V1902_EXTERNAL_PIN_RELEASE\n",1)[1].split(
        "V1902_END_PIN_RELEASE\n",1)[0]
    observed = [int(x,8) for x in re.findall(
        r"(?m)^%o:\s*([0-7]{12})\s*$"%exp["source_meta"],released)]
    if observed != [exp["source_pin1"]]:
        raise ValueError("original external pin release did not start from pin1")
    # The test-only SIMH 'deposit' does not emit a second examine
    # implicitly. The subsequent independent original MM snapshot at
    # the REAL native target-free call must prove source pin0; never
    # replace that evidence with a fabricated post-deposit transcript.
    release_command = ("deposit %06o %012o\n" %
                       (exp["source_meta"], exp["source_pin0"]))
    ini = (work / "physical.ini").read_text(encoding="ascii")
    if ini.count(release_command) != 1:
        raise ValueError("test-only source pin release not uniquely configured")
    if event_word(trace,"V1902REC_ORIGINAL_NATIVE_PROCESS_FREE_RETURN",
                  "V1902REC_STAGE_TARGET_FREED",1) != 0:
        raise ValueError("original native MM target free did not return MM_OK")
    for label in ("BEFORE_TARGET_FREE","TARGET_FREED","TRANSITION_UNLOCKED"):
        section = stage_text(trace,"V1902REC",label)
        if word(section,core["proc_current_slot"]) != 0:
            raise ValueError("native scratch reconciliation not executed on slot0")
    pinned = stage_text(trace,"V1902","PINNED_HB")
    before_recovery = stage_text(trace,"V1902REC","BEFORE_TARGET_FREE")
    final = stage_text(trace,"V1902REC","PARENT_AFTER_RECOVERY")
    if word(pinned,core["proc_current_slot"]) != 1 or \
            word(final,core["proc_current_slot"]) != 1 or \
            word(final,core["proc_timer_clock"]) <= \
            word(before_recovery,core["proc_timer_clock"]):
        raise ValueError("original parent lost autonomous user HB/PCLK progress")
    print("PASS v1902: original MM source -5 / PIN1->PIN0, exact target native free 0")
    print("v1902: original idle reaper PURE recovery, MM 18->17, TRANSITION clear")
    print("v1902: original saved executive PC/FDCTL unchanged, parent HB/PCLK progress")
    print("NOT PROVEN: true foreign TERM after restoration or 5-child WAIT/HALT")


if __name__ == "__main__":
    if len(sys.argv) != 4:
        raise SystemExit("usage: verify-physical-commit-v1902.py kit source-build physical-work")
    try:
        read(*(Path(x) for x in sys.argv[1:]))
    except (ValueError,KeyError,OSError,UnicodeError,AssertionError) as e:
        raise SystemExit("FAIL v1902 real PDP6 native MM reconcile physical: " + str(e))
