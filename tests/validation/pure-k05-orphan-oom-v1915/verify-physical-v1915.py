#!/usr/bin/env python3
"""Check genuine user BRK capacity OOM cannot steal a foreign FULL owner."""

from pathlib import Path
import hashlib
import re
import runpy
import sys


def verify(kit, build, work):
    link = runpy.run_path(str(kit / "tests/validation/"
                           "pure-k05-secondary-physical-v1845/prepare-v1845.py"))
    prior = runpy.run_path(str(kit / "tests/validation/"
                            "pure-k05-foreign-target-v1906/verify-physical-v1906.py"))
    mm = runpy.run_path(str(kit / "tests/diagnostics/"
                         "pure-full-restore-v1638/audit-v1638.py"))
    core = link["symbols"](build / "kcore.map")
    user = link["symbols"](build.parent / "user/init.map")
    word,section,values = prior["word"],prior["section"],prior["values"]
    e = values(work / "expected-v1906.txt")
    term = values(work / "expected-v1907.txt")
    want = values(work / "expected-v1915.txt")
    transcript = (work / "physical.clean").read_text(encoding="ascii")
    script = (work / "physical.ini").read_text(encoding="ascii")
    guest = (build.parent / "user/init-v1614.c").read_text(encoding="ascii")
    if hashlib.sha256((build / "kcore.dxr").read_bytes()).hexdigest() != \
       "a201a7fdcf481b436b06694e5dd55c9367036ebd9f64c630486f854b1a4f89be" or \
       hashlib.sha256((build / "pure-mres-v1612.dxr").read_bytes()).hexdigest() != \
       "09f65d0ca272986b462c63580eae3c4006490004cd060529ce40f10a55949351":
        raise ValueError("original KCORE/PURE binaries are not source-identical")
    if want != {
            "pressure_gate":0o130000+user["v1901_term_gate"],
            "pressure_value":0o76543012765,
            "brk_target":0o130000,
            "mm_fits_pc":core["mm_arena_fits_v1260"],
            "fatal_pc":core["proc_fatal_close_current_v879"],
            "exit_pc":core["proc_exit_current"],
            "idle_pc":core["proc_idle_loop"],
            "retry_pc":core["proc_finish_service_v881"],
            "pi6_pc":core["proc_sched_pi_tick"]} or \
       term["wait_gate"] != want["pressure_gate"] or \
       e["process_table"] != 0o45700 or e["uarea"] != 0o47017:
        raise ValueError("native OOM and USER gate addresses not source-linked")
    if guest.count("v1901_term_gate == 076543012765UL")!=1 or \
       guest.count("(void)dsys_brk(0130000UL);")!=1 or \
       guest.count("p14_fail('O');")!=1 or \
       guest.count("SYS_EVENT_ARG(3U, SYS_EVENT_TERM)")!=2 or \
       script.count("deposit %06o %012o\n" %
                    (want["pressure_gate"],want["pressure_value"]))!=1 or \
       script.count("deposit %06o %012o\n" %
                    (e["target_meta"],0o1000002))!=1 or \
       script.count("examine %06o-%06o\n" %
                    (e["process_table"],e["process_table"]+0o26))!=17 or \
       len(re.findall(r"(?m)^echo V1915_STAGE_[A-Z0-9_]+$",script))!=17 or \
       script.count("V1906_FOREIGN_TARGET_REPAIR")!=0 or \
       not script.endswith("echo V1915_OPERATOR_STOP_WITH_FOREIGN_OWNER\nexit\n"):
        raise ValueError("original one-shot user OOM/foreign-owner script not exact")
    if "HALT instruction" in transcript or \
       "V1906_ORIGINAL_TRANSITION_CLEAR" in transcript or \
       re.search(r"![A-Za-z0-9]",transcript):
        raise ValueError("unexpected guest HALT, premature restore or user failure")
    names = ["V1902_REAL_MM_FREE_REFUSED",
             "V1906_FOREIGN_TARGET_INJECT",
             "V1907_ORIGINAL_USER_TERM_REFUSED",
             "V1915_USER_PRESSURE_GATE_BEFORE",
             "V1915_USER_PRESSURE_GATE_ARMED",
             "V1915_ACTUAL_PARENT_USER_BRK_REQUEST",
             "V1915_ORIGINAL_MM_ARENA_FITS",
             "V1915_ORIGINAL_REQUESTER_ONLY_OOM",
             "V1915_REAL_PARENT_FATAL_EXIT",
             "V1915_ORIGINAL_PARENT_OOM_RELEASED"]
    for i in range(1,4):
        names.extend(("V1915_REAL_PEER_EXIT_%02d" % i,
                      "V1915_REAL_PEER_DONE_%02d" % i))
    for i in range(1,4):
        names.extend(("V1915_ORIGINAL_IDLE_RETRY_%02d" % i,
                      "V1915_ORIGINAL_RETRY_DONE_%02d" % i))
    names.extend(("V1915_ORIGINAL_LAST_ORPHAN_PI6",
                  "V1915_OPERATOR_STOP_WITH_FOREIGN_OWNER"))
    positions = [transcript.find(name+"\n") for name in names]
    if any(p<0 or transcript.count(name+"\n")!=1
           for name,p in zip(names,positions)) or positions!=sorted(positions):
        raise ValueError("real foreign/TERM/BRK/OOM/EXIT/retry order not unique")
    for key,n in (("mm_fits_pc",1),("fatal_pc",1),("exit_pc",4),
                  ("idle_pc",7),("retry_pc",3)):
        if len(re.findall(r"Breakpoint, PC: %06o " % want[key],transcript))!=n:
            raise ValueError("native KCORE instruction breakpoint missing: "+key)
    if not re.search(r"TR\s*V1907_ORIGINAL_USER_TERM_REFUSED",transcript) or \
       not re.search(r"P\s*V1915_ACTUAL_PARENT_USER_BRK_REQUEST",transcript):
        raise ValueError("real user TERM refusal or parent BRK call absent")
    if word(section(transcript,"V1902_REAL_MM_FREE_REFUSED",
                    "V1902_STAGE_NATIVE_REFUSED"),1)!=0o777777777773:
        raise ValueError("original source PACKED free did not return -5")

    def stage(prefix,name):
        scalar,owners = mm["stage"](
            transcript.replace(prefix+"_","V1638_"),core,name)
        part = section(transcript,prefix+"_STAGE_"+name,
                       prefix+"_END_"+name)
        return scalar,owners,part

    original = stage("V1907","TERM_REFUSED")
    capacity = stage("V1915","MM_ARENA_FITS")
    fatal = stage("V1915","OOM_REQUESTER")
    parent_exit = stage("V1915","PARENT_EXIT")
    gone = stage("V1915","PARENT_GONE")
    peer_exit = [stage("V1915","PEER_EXIT_%02d"%i) for i in range(1,4)]
    peer_done = [stage("V1915","PEER_DONE_%02d"%i) for i in range(1,4)]
    retries = [stage("V1915","IDLE_RETRY_%02d"%i) for i in range(1,4)]
    retry_done = [stage("V1915","RETRY_DONE_%02d"%i) for i in range(1,4)]
    last_pi6 = stage("V1915","LAST_PI6")
    raw=(0o111200,0o120000,4,0,3)
    foreign=(0o120000,0o130000,1,0,2)
    root=original[0][core["vfs_namespace_root"]]
    expected_private = {
        e["uarea"]+0o20:0o340000016704,
        e["uarea"]+0o24:0o4010,
        e["uarea"]+0o67:0o40000120000}
    for name,record in ([ ("TERM",original),("MM FITS",capacity),
                         ("fatal",fatal),("parent exit",parent_exit),
                         ("parent gone",gone)] +
                        [("peer EXIT%d"%i,x) for i,x in enumerate(peer_exit,1)] +
                        [("peer done%d"%i,x) for i,x in enumerate(peer_done,1)] +
                        [("retry%d"%i,x) for i,x in enumerate(retries,1)] +
                        [("retry done%d"%i,x) for i,x in enumerate(retry_done,1)] +
                        [("PI6",last_pi6)]):
        scalar,owners,part=record
        if owners.count(raw)!=1 or owners.count(foreign)!=1 or \
           scalar[core["vfs_namespace_root"]]!=root or \
           not (word(part,e["process_table"]+9)&(1<<16)) or \
           (word(part,e["process_table"]+10)&0o777777)!=0:
            raise ValueError("foreign FULL ownership/ROOT/TRANSITION lost at "+name)
        for addr,value in expected_private.items():
            if word(part,addr)!=value:
                raise ValueError("private executive context/escrow lost at "+name)
    if original[0][core["mm_extent_count"]]!=18 or \
       capacity[0][core["mm_extent_count"]]!=18 or \
       fatal[0][core["mm_extent_count"]]!=18 or \
       word(capacity[2],core["proc_table"])!=e["process_table"] or \
       capacity[1]!=original[1] or fatal[1]!=original[1]:
        raise ValueError("capacity-OOM mutated other MM owners before fatal EXIT")
    before=section(transcript,"V1915_USER_PRESSURE_GATE_BEFORE",
                   "V1915_END_USER_PRESSURE_GATE_BEFORE")
    armed=section(transcript,"V1915_USER_PRESSURE_GATE_ARMED",
                  "V1915_END_USER_PRESSURE_GATE_ARMED")
    if word(before,want["pressure_gate"])!=0 or \
       word(armed,want["pressure_gate"])!=want["pressure_value"]:
        raise ValueError("USER pressure gate not armed AFTER foreign-owner refusal")
    mm_entry=section(transcript,"V1915_ORIGINAL_MM_ARENA_FITS",
                     "V1915_STAGE_MM_ARENA_FITS")
    if word(mm_entry,1)!=want["brk_target"] or \
       word(mm_entry,2)!=0o2000 or \
       capacity[0][core["proc_current_slot"]]!=1:
        raise ValueError("native arena-fit check did not receive legal BRK APR")
    # Prove the request is physically impossible using the original
    # live hardware arena descriptors. This distinguishes MM capacity
    # OOM from an invalid logical BRK argument or a fabricated reply.
    arena_count=word(capacity[2],core["mm_arena_count"])
    if not 1<=arena_count<=3:
        raise ValueError("original physical arena count invalid")
    for i in range(arena_count):
        arena=word(capacity[2],core["mm_arenas"]+i)
        base=arena&0o777777
        size=(arena>>18)&0o777777
        aligned=(base+0o1777)&~0o1777
        if size==0 or aligned<=base+size and \
           want["brk_target"]<=base+size-aligned:
            raise ValueError("BRK APR was not impossible in this real arena")
    fatal_entry=section(transcript,"V1915_ORIGINAL_REQUESTER_ONLY_OOM",
                        "V1915_STAGE_OOM_REQUESTER")
    if word(fatal_entry,1)!=1 or fatal[0][core["proc_current_slot"]]!=1 or \
       parent_exit[0][core["proc_current_slot"]]!=1:
        raise ValueError("original BRK did not take requester-only OOM fatal path")
    if gone[0][core["mm_extent_count"]]!=16 or \
       gone[0][core["proc_current_slot"]]!=0 or \
       word(gone[2],e["process_table"]+3)!=0 or \
       [x for x in original[1] if x not in gone[1]]!=[
           (0o45761,0o46371,3,0,0o1001),
           (0o130000,0o140000,1,0,1)] or \
       [x for x in gone[1] if x not in original[1]]:
        raise ValueError("OOM fatal EXIT did not retire only the requester")
    child_slots=[x[0][core["proc_current_slot"]] for x in peer_exit]
    if set(child_slots)!={4,5,6}:
        raise ValueError("not three distinct original healthy child exits")
    for i,done in enumerate(peer_done):
        if done[0][core["proc_current_slot"]]!=0 or \
           word(done[2],e["process_table"]+3*child_slots[i])!=0:
            raise ValueError("original healthy child did not finish EXIT before next")
    orphan=peer_done[-1]
    if orphan[0][core["mm_extent_count"]]!=10 or \
       word(orphan[2],core["proc_high_slot"])!=4 or \
       word(orphan[2],e["process_table"]+9)!=0o47017600001:
        raise ValueError("last LIVE foreign child not conserved after all EXIT")
    if [x for x in gone[1] if x not in orphan[1]] != [
           (0o47427,0o50037,3,0,0o1004),
           (0o50037,0o50447,3,0,0o1005),
           (0o50447,0o51057,3,0,0o1006),
           (0o61200,0o70000,4,0,6),
           (0o71200,0o100000,4,0,5),
           (0o101200,0o110000,4,0,4)] or \
       [x for x in orphan[1] if x not in gone[1]]:
        raise ValueError("healthy peer EXIT changed unrelated physical MM extents")
    for i,x in enumerate(retries+retry_done+[last_pi6]):
        scalar,owners,part=x
        if owners!=orphan[1] or scalar[core["mm_extent_count"]]!=10 or \
           scalar[core["proc_current_slot"]]!=0 or \
           word(part,core["proc_high_slot"])!=4:
            raise ValueError("held last orphan MM10 changed at checkpoint %d"%i)
        for slot in (1,2,4,5,6):
            if word(part,e["process_table"]+3*slot)!=0:
                raise ValueError("retired process resurrected during last orphan")
    clock=[word(x[2],core["proc_timer_clock"]) for x in retries]
    if len(clock)!=3 or clock[1]-clock[0]!=0o1000 or \
       clock[2]-clock[1]!=0o1000:
        raise ValueError("native last-orphan retries violated capped PCLK interval")
    for scalar,owners,part in retries+retry_done+[last_pi6]:
        pending=word(part,core["proc_timer_clock"]+2)
        if not(pending&(1<<35)) or \
           ((pending>>18)&0o377777)!=0o1000:
            raise ValueError("source-linked foreign retry pending/backoff lost")
    pi6=word(section(transcript,"V1915_ORIGINAL_LAST_ORPHAN_PI6",
                     "V1915_STAGE_LAST_PI6"),core["pdp10_pi_level6"])
    pc=pi6&0o777777
    if not core["proc_idle_loop"]<=pc<core[
            "proc_finish_backoff_advance_v885"] or pi6&(0o10000<<18):
        raise ValueError("native last orphan PI6 did not interrupt idle")
    print("PASS v1915: source-built original parent BRK(0130000) capacity failure")
    print("PASS v1915: original MM arena fit request and requester-only native OOM")
    print("PASS v1915: original fatal parent EXIT released only its own MM")
    print("PASS v1915: real healthy child EXIT x3, foreign orphan MM10 retained")
    print("PASS v1915: three native clock-capped orphan retries, no guest HALT")


if __name__=="__main__":
    if len(sys.argv)!=4:
        raise SystemExit("usage: verify-physical-v1915.py kit build work")
    try:
        verify(*(Path(x) for x in sys.argv[1:]))
    except (OSError,ValueError,KeyError,AssertionError,UnicodeError) as exc:
        raise SystemExit("FAIL v1915 native orphan OOM: "+str(exc))
