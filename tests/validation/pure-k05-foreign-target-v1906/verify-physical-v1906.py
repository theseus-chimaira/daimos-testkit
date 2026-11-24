#!/usr/bin/env python3
"""Audit actual 48K PDP-6 escrow, foreign claim, repair and typed WAIT."""

from pathlib import Path
import hashlib
import re
import runpy
import sys


def word(text, addr):
    found = re.findall(r"(?m)^%o:\s*([0-7]{12})\s*$" % addr,text)
    if not found or len(set(found)) != 1:
        raise ValueError("original physical word absent/ambiguous: %06o" % addr)
    return int(found[0],8)


def section(trace, first, last):
    a, b = first+"\n",last+"\n"
    if trace.count(a)!=1 or trace.count(b)!=1:
        raise ValueError("physical checkpoint not unique: " + first)
    return trace.split(a,1)[1].split(b,1)[0]


def values(path):
    return dict((name,int(value,8)) for name,value in re.findall(
        r"(?m)^([a-z0-9_]+)\s+([0-7]+)$",
        path.read_text(encoding="ascii")))


def verify(kit, build, work):
    old = runpy.run_path(str(kit / "tests/validation/"
                       "pure-k05-secondary-physical-v1845/prepare-v1845.py"))
    audit = runpy.run_path(str(kit / "tests/diagnostics/"
                         "pure-full-restore-v1638/audit-v1638.py"))
    core = old["symbols"](build/"kcore.map")
    e = values(work/"expected-v1906.txt")
    first = values(work/"expected-v1902.txt")
    transcript = (work/"physical.clean").read_text(encoding="ascii")
    ini = (work/"physical.ini").read_text(encoding="ascii")
    if hashlib.sha256((build/"kcore.dxr").read_bytes()).hexdigest() != \
            "a201a7fdcf481b436b06694e5dd55c9367036ebd9f64c630486f854b1a4f89be" or \
            hashlib.sha256((build/"pure-mres-v1612.dxr").read_bytes()).hexdigest() != \
            "09f65d0ca272986b462c63580eae3c4006490004cd060529ce40f10a55949351":
        raise ValueError("original fixed KCORE/PURE escrow binaries changed")
    if e["source_meta"] != core["mm_extents"]+0o37 or \
            e["target_meta"] != core["mm_extents"]+0o41 or \
            e["parent_gate"] != 0o130000 + \
                old["symbols"](build.parent/"user/init.map")["v1901_term_gate"]:
        raise ValueError("source-linked MM target/USER gate not exact")
    if ini.count("deposit %06o %012o\n" %
                 (e["target_meta"],0o1000002)) != 1 or \
            ini.count("deposit %06o %012o\n" %
                      (e["target_meta"],0o1000003)) != 1 or \
            ini.count("deposit %06o %012o\n" %
                      (e["source_meta"],first["source_pin0"])) != 1 or \
            ini.count("deposit %06o %012o\n" %
                      (e["parent_gate"],0o12345670123)) != 1 or \
            "nobreak\n" in ini:
        raise ValueError("native fault-injection escaped controlled owner/gate")
    markers = ("V1845_END_FULL_PINNED",
               "V1902_NATIVE_SOURCE_FREE_CALL", "V1902_REAL_MM_FREE_REFUSED",
               "V1902_ORIGINAL_FAILED_FULL_RETURN",
               "V1902_REAL_PARENT_HEARTBEAT_PINNED",
               "V1902_EXTERNAL_PIN_RELEASE", "V1906_FOREIGN_TARGET_INJECT",
               "V1906_END_FOREIGN_TARGET_INJECT",
               "V1906_FOREIGN_HELD_HB_1","V1906_END_FOREIGN_HELD_HB_1",
               "V1906_FOREIGN_HELD_HB_2","V1906_END_FOREIGN_HELD_HB_2",
               "V1906_FOREIGN_HELD_HB_3","V1906_END_FOREIGN_HELD_HB_3",
               "V1906_FOREIGN_TARGET_REPAIR","V1906_END_FOREIGN_TARGET_REPAIR",
               "V1906_ORIGINAL_NATIVE_TARGET_FREE_CALL",
               "V1906_ORIGINAL_NATIVE_TARGET_FREE_RETURN",
               "V1906_ORIGINAL_TRANSITION_CLEAR",
               "V1906_ORIGINAL_PARENT_AFTER_RECOVERY",
               "V1906_SECOND_NATIVE_SOURCE_FREE_RETURN",
               "V1906_SECOND_FULL_SERVICE_RETURN",
               "V1906_TEST_ONLY_PARENT_USER_GATE",
               "V1906_END_PARENT_USER_GATE",
               "V1906_ORIGINAL_PARENT_TYPED_WAIT_Z",
               "V1906_ORIGINAL_NATIVE_HALT")
    keys = [x+"\n" for x in markers]
    if any(transcript.count(x)!=1 for x in keys) or \
            [transcript.index(x) for x in keys] != sorted(
                transcript.index(x) for x in keys):
        raise ValueError("original fail-closed/repair/lifecycle sequence not ordered")
    for name in ("target_call","transition_clear","source_return",
                 "service_return"):
        if not re.search(r"Breakpoint, PC: %06o " % e[name],transcript):
            raise ValueError("original compiled checkpoint not reached: " + name)
    if word(section(transcript,"V1902_REAL_MM_FREE_REFUSED",
                    "V1902_STAGE_NATIVE_REFUSED"),1) != 0o777777777773:
        raise ValueError("original PACKED source free did not return -5")
    if word(section(transcript,"V1906_ORIGINAL_NATIVE_TARGET_FREE_RETURN",
                    "V1906_STAGE_TARGET_FREED"),1) != 0 or \
            word(section(transcript,"V1906_SECOND_NATIVE_SOURCE_FREE_RETURN",
                    "V1906_STAGE_SOURCE_FREED"),1) != 0:
        raise ValueError("genuine native target/source frees did not commit")
    if word(section(transcript,"V1906_FOREIGN_TARGET_INJECT",
                    "V1906_END_FOREIGN_TARGET_INJECT"),e["target_meta"]) != \
            0o1000003 or \
            word(section(transcript,"V1906_FOREIGN_TARGET_REPAIR",
                    "V1906_END_FOREIGN_TARGET_REPAIR"),e["target_meta"]) != \
            0o1000002:
        raise ValueError("foreign target not actually claimed/repaired")

    def capture(prefix,name):
        scalar,extents = audit["stage"](
            transcript.replace(prefix+"_","V1638_"),core,name)
        block = section(transcript,prefix+"_STAGE_"+name,
                        prefix+"_END_"+name)
        return scalar,extents,block

    prior,prior_ext,_ = capture("V1902","PINNED_HB")
    initial_packed = (0o111200,0o120000,4,1,3)
    packed = (0o111200,0o120000,4,0,3)
    process = (0o120000,0o130000,1,0,3)
    foreign = (0o120000,0o130000,1,0,2)
    if prior_ext.count(initial_packed)!=1 or prior_ext.count(process)!=1:
        raise ValueError("original failed FULL does not retain both owners")
    want_foreign = [packed if x==initial_packed else
                    foreign if x==process else x for x in prior_ext]
    want_owned = [packed if x==initial_packed else x for x in prior_ext]
    want_single = [x for x in want_owned if x!=process]
    want_restored = [x for x in want_owned if x!=packed]
    root = prior[core["vfs_namespace_root"]]
    saved = None
    clocks = []
    intervals = []
    for i in (1,2,3):
        scalar,extent,t = capture("V1906","FOREIGN_HELD_HB_%d"%i)
        if extent!=want_foreign or scalar[core["mm_extent_count"]]!=18 or \
                scalar[core["proc_current_slot"]]!=1 or \
                scalar[core["vfs_namespace_root"]]!=root or \
                word(t,core["proc_table"])!=e["process_table"] or \
                (word(t,e["process_table"]+9)>>18)!=e["uarea"] or \
                not (word(t,e["process_table"]+9)&(1<<16)) or \
                (word(t,e["process_table"]+10)&0o777777) or \
                word(t,e["parent_gate"])!=0:
            raise ValueError("foreign claimed owner was released/unlocked at HB%d"%i)
        ctx=(word(t,e["uarea"]+0o20),word(t,e["uarea"]+0o24),
             word(t,e["uarea"]+0o67))
        if saved is None:
            saved=ctx
            if (ctx[0]>>18)&0o10000 or \
                    ctx[2] != (1<<32)|0o120000:
                raise ValueError("native escrow or private executive PC absent")
        if saved!=ctx:
            raise ValueError("foreign claim corrupted saved CTX_PC/FDCTL/escrow")
        timer=word(t,core["proc_timer_clock"]+2)
        interval=(timer>>18)&0o377777
        if not (timer&(1<<35)) or interval==0 or interval>0o1000 or \
                (interval&(interval-1)):
            raise ValueError("original bounded slot0 backoff lost pending owner")
        intervals.append(interval)
        clocks.append(word(t,core["proc_timer_clock"]))
    if not clocks[0]<clocks[1]<clocks[2] or \
            not intervals[0]<intervals[1]<=intervals[2]:
        raise ValueError("foreign owner starved original parent/clock/backoff")
    before,before_ext,before_t = capture("V1906","BEFORE_TARGET_FREE")
    freed,freed_ext,freed_t = capture("V1906","TARGET_FREED")
    unlocked,unlocked_ext,unlocked_t = capture("V1906","UNLOCKED")
    parent,parent_ext,parent_t = capture("V1906","PARENT_HB")
    source,source_ext,source_t = capture("V1906","SOURCE_FREED")
    resident,resident_ext,resident_t = capture("V1906","FULL_COMMITTED")
    done,done_ext,done_t = capture("V1906","PARENT_Z")
    halted,halted_ext,halted_t = capture("V1906","HALT")
    for name,scalar,extent,want,count in (
            ("before free",before,before_ext,want_owned,18),
            ("target freed",freed,freed_ext,want_single,17),
            ("unlocked",unlocked,unlocked_ext,want_single,17),
            ("parent",parent,parent_ext,want_single,17),
            ("source freed",source,source_ext,want_restored,17),
            ("committed",resident,resident_ext,want_restored,17)):
        if extent!=want or scalar[core["mm_extent_count"]]!=count or \
                scalar[core["vfs_namespace_root"]]!=root:
            raise ValueError("original MM owner/root drifted: " + name)
    if not (word(before_t,e["process_table"]+9)&(1<<16)) or \
            word(before_t,e["uarea"]+0o67)!=(1<<32)|0o120000 or \
            word(freed_t,e["uarea"]+0o67)!=(1<<32)|0o120000 or \
            (word(unlocked_t,e["process_table"]+9)&(1<<16)) or \
            word(unlocked_t,e["uarea"]+0o67)!=0:
        raise ValueError("original escrow retired before exact target free")
    for t in (before_t,freed_t,unlocked_t,parent_t):
        if word(t,e["uarea"]+0o20)!=saved[0] or \
                word(t,e["uarea"]+0o24)!=saved[1]:
            raise ValueError("original private continuation was not conserved")
    if not (word(source_t,e["process_table"]+9)&(1<<16)) or \
            (word(resident_t,e["process_table"]+9)&(1<<16)) or \
            (word(resident_t,e["process_table"]+10)&0o777777)!=0o120000:
        raise ValueError("original second FULL did not publish RESIDENT APR")
    for t in (before_t,freed_t,unlocked_t,parent_t,source_t,resident_t):
        if word(t,e["parent_gate"])!=0:
            raise ValueError("typed WAIT gate opened before real FULL commit")
    gate = section(transcript,"V1906_TEST_ONLY_PARENT_USER_GATE",
                   "V1906_END_PARENT_USER_GATE")
    if word(gate,e["parent_gate"])!=0:
        raise ValueError("test-only parent gate was not originally zero")
    if any(owner==3 and typ in (1,4) for a,b,typ,pins,owner in done_ext) or \
            any(owner==3 and typ in (1,4) for a,b,typ,pins,owner in halted_ext):
        raise ValueError("original typed EXIT/WAIT/HALT leaked child MM owner")
    if done[core["mm_extent_count"]]!=8 or \
            halted[core["mm_extent_count"]]!=6 or \
            done[core["vfs_namespace_root"]]!=root or \
            halted[core["vfs_namespace_root"]]!=root:
        raise ValueError("original child/parent cleanup failed MM/ROOT")
    progress=section(transcript,"V1845_END_A",
                     "V1906_ORIGINAL_PARENT_TYPED_WAIT_Z")
    if progress.count("w")!=5 or not progress.endswith("Z") or \
            "!" in progress or \
            "HALT instruction, PC: 000000" not in transcript:
        raise ValueError("five typed WAITs and real PDP6 HALT absent")
    print("PASS v1906: genuine source-free -5, foreign target owner2 conserved")
    print("PASS v1906: native escrow 120000 and TRANSITION held across three HBs")
    print("PASS v1906: test-only owner repair, real native PROCESS free 0")
    print("PASS v1906: original second FULL RESIDENT, five typed WAIT, Z/HALT")


if __name__ == "__main__":
    if len(sys.argv)!=4:
        raise SystemExit("usage: verify-physical-v1906.py kit build work")
    try:
        verify(*(Path(s) for s in sys.argv[1:]))
    except (OSError,ValueError,KeyError,AssertionError,UnicodeError) as exc:
        raise SystemExit("FAIL v1906 original PDP6 escrow physical: " + str(exc))
