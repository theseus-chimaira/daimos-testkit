#!/usr/bin/env python3
"""Check genuine last-user orphan, idle retries and real PCLK PI6."""

from pathlib import Path
import hashlib
import re
import runpy
import sys


def verify(kit, build, work):
    old = runpy.run_path(str(kit / "tests/validation/"
                         "pure-k05-foreign-target-v1906/verify-physical-v1906.py"))
    maptools = runpy.run_path(str(kit / "tests/validation/"
                         "pure-k05-secondary-physical-v1845/prepare-v1845.py"))
    audit = runpy.run_path(str(kit / "tests/diagnostics/"
                         "pure-full-restore-v1638/audit-v1638.py"))
    core = maptools["symbols"](build / "kcore.map")
    word = old["word"]
    section = old["section"]
    values = old["values"]
    first = values(work / "expected-v1906.txt")
    parent = values(work / "expected-v1910.txt")
    expected = values(work / "expected-v1911.txt")
    trace = (work / "physical.clean").read_text(encoding="ascii")
    script = (work / "physical.ini").read_text(encoding="ascii")
    if hashlib.sha256((build / "kcore.dxr").read_bytes()).hexdigest()!= \
       "a201a7fdcf481b436b06694e5dd55c9367036ebd9f64c630486f854b1a4f89be" or \
       hashlib.sha256((build / "pure-mres-v1612.dxr").read_bytes()).hexdigest()!= \
       "09f65d0ca272986b462c63580eae3c4006490004cd060529ce40f10a55949351":
        raise ValueError("original KCORE/PURE no longer unchanged from v1910")
    if expected != {"table":0o45700,"child_slot":3,
             "child_exit_pc":core["proc_exit_current"],
             "idle_pc":core["proc_idle_loop"],
             "retry_pc":core["proc_finish_service_v881"],
             "pi6_pc":core["proc_sched_pi_tick"],
             "pending":core["proc_timer_clock"]+2,
             "clock":core["proc_timer_clock"],
             "live_check":core["proc_has_live_user"]} or \
       first["process_table"]!=expected["table"] or \
       first["uarea"]!=0o47017 or parent["parent_meta"]!=0o45703:
        raise ValueError("original last-user physical maps not source-linked")
    if script.count("deposit %06o %012o\n" %
                    (first["target_meta"],0o1000002))!=1 or \
       script.count("deposit %06o %012o\n" %
                    (parent["exit_gate"],parent["exit_value"]))!=1 or \
       "V1906_FOREIGN_TARGET_REPAIR" in script or \
       "V1906_ORIGINAL_NATIVE_TARGET_FREE_CALL" in script or \
       script.count("break %06o\n" % expected["child_exit_pc"])!=4 or \
       script.count("break %06o\n" % expected["retry_pc"])!=3 or \
       script.count("break %06o\n" % expected["idle_pc"])!=7 or \
       not script.endswith("echo V1911_OPERATOR_STOP_NO_CHILD_HALT\nexit\n"):
        raise ValueError("not three original child EXIT/idle/PI6 events")
    names = ("V1902_REAL_MM_FREE_REFUSED",
             "V1906_FOREIGN_TARGET_INJECT",
             "V1907_ORIGINAL_USER_TERM_REFUSED",
             "V1910_ORIGINAL_PARENT_EXIT_CURRENT",
             "V1910_ORIGINAL_SLOT0_OWNER_FINALIZER",
             "V1910_ORIGINAL_PARENT_EXIT_IDLE",
             "V1910_ORIGINAL_POST_EXIT_PI6")
    for i in range(1,4):
        names+=("V1911_REAL_CHILD_EXIT_%d" % i,)
        names+=( ("V1911_ORIGINAL_CHILD_DONE_%d" % i)
                 if i<3 else "V1911_ORIGINAL_LAST_ORPHAN_IDLE",)
    for i in range(1,4):
        names+=("V1911_ORIGINAL_IDLE_RETRY_%d" % i,
                "V1911_ORIGINAL_RETRY_COMPLETED_%d" % i)
    names += ("V1911_ORIGINAL_LAST_ORPHAN_PI6",
              "V1911_OPERATOR_STOP_NO_CHILD_HALT")
    marks = [trace.find(n+"\n") for n in names]
    if any(i<0 or trace.count(n+"\n")!=1 for i,n in zip(marks,names)) or \
       marks!=sorted(marks):
        raise ValueError("missing/incorrect original child EXIT or last idle order")
    for name,count in (("child_exit_pc",4),("idle_pc",7),
                       ("retry_pc",3),("pi6_pc",2)):
        if len(re.findall("Breakpoint, PC: %06o " % expected[name],trace))!=count:
            raise ValueError("genuine KCORE breakpoint not reached: "+name)
    if "HALT instruction" in trace or \
       "V1906_ORIGINAL_TRANSITION_CLEAR" in trace or \
       re.search(r"!([0-9a-zA-Z])",trace):
        raise ValueError("unexpected guest HALT/failure/unlocked owner")
    if word(section(trace,"V1902_REAL_MM_FREE_REFUSED",
                    "V1902_STAGE_NATIVE_REFUSED"),1)!=0o777777777773 or \
       word(section(trace,"V1906_FOREIGN_TARGET_INJECT",
                    "V1906_END_FOREIGN_TARGET_INJECT"),
            first["target_meta"])!=0o1000003:
        raise ValueError("original failed FULL or foreign target not authentic")
    if not re.search(r"TR\s*V1907_ORIGINAL_USER_TERM_REFUSED",trace) or \
       not re.search(r"E\s*V1910_REAL_PARENT_USER_EXIT_REQUEST",trace):
        raise ValueError("missing actual original parent TERM refusal or SYS_EXIT")

    def stage(prefix,name):
        info,owners=audit["stage"](trace.replace(prefix+"_","V1638_"),
                                    core,name)
        part=section(trace,prefix+"_STAGE_"+name,prefix+"_END_"+name)
        return info,owners,part

    parent_gone=stage("V1910","POST_EXIT_PI6")
    child_stages=[stage("V1911","CHILD_EXIT_%d" % i) for i in range(1,4)]
    child_done=[stage("V1911","CHILD_DONE_%d" % i) for i in range(1,3)]
    orphan=stage("V1911","ONLY_ORPHAN")
    retries=[stage("V1911","IDLE_RETRY_%d" % i) for i in range(1,4)]
    retry_done=[stage("V1911","RETRY_DONE_%d" % i) for i in range(1,4)]
    final_pi=stage("V1911","LAST_PI6")
    raw=(0o111200,0o120000,4,0,3)
    foreign=(0o120000,0o130000,1,0,2)
    expected_ctx={first["uarea"]+0o20:0o340000016704,
                  first["uarea"]+0o24:0o4010,
                  first["uarea"]+0o67:0o40000120000}
    root=parent_gone[0][core["vfs_namespace_root"]]
    for label,(scalar,owners,part) in ([ ("parent",parent_gone) ]+
                [ ("child%d"%(i+1),s) for i,s in enumerate(child_stages) ]+
                [ ("child-done%d"%(i+1),s) for i,s in enumerate(child_done) ]+
                [ ("orphan",orphan) ]+
                [ ("retry%d"%(i+1),s) for i,s in enumerate(retries) ]+
                [ ("retry-done%d"%(i+1),s) for i,s in enumerate(retry_done) ]+
                [ ("last-pi6",final_pi) ]):
        if owners.count(raw)!=1 or owners.count(foreign)!=1 or \
           scalar[core["vfs_namespace_root"]]!=root or \
           (word(part,expected["table"]+9)&0o200000)==0 or \
           (word(part,expected["table"]+9)&0o177400)!=0 or \
           word(part,expected["table"]+10)!=0o10000000000:
            raise ValueError("original child orphan MM/transition/VM lost: "+label)
        for addr,value in expected_ctx.items():
            if word(part,addr)!=value:
                raise ValueError("saved child executive ctx or escrow lost: "+label)
    before=parent_gone[1]
    if parent_gone[0][core["mm_extent_count"]]!=16:
        raise ValueError("original v1910 parent cleanup not completed")
    if orphan[0][core["mm_extent_count"]]!=10 or \
       [extent for extent in before if extent not in orphan[1]]!=[
           (0o47427,0o50037,3,0,0o1004),
           (0o50037,0o50447,3,0,0o1005),
           (0o50447,0o51057,3,0,0o1006),
           (0o61200,0o70000,4,0,6),
           (0o71200,0o100000,4,0,5),
           (0o101200,0o110000,4,0,4)] or \
       [extent for extent in orphan[1] if extent not in before]:
        raise ValueError("last-user teardown must free exactly six sibling extents")
    slots=[]
    for i,(scalar,owners,part) in enumerate(child_stages,1):
        slot=word(part,core["proc_current_slot"])
        slots.append(slot)
        if slot not in (4,5,6):
            raise ValueError("not a genuine nonquarantined child EXIT")
    if set(slots)!={4,5,6}:
        raise ValueError("duplicate child EXIT or missing orphan sibling")
    for i,completed in enumerate(child_done):
        scalar,owners,part=completed
        if scalar[core["proc_current_slot"]]!=0 or \
           word(part,expected["table"]+3*slots[i])!=0:
            raise ValueError("child EXIT did not complete before next checkpoint")
    for label,(scalar,owners,part) in ([ ("orphan",orphan) ]+
               [ ("retry%d"%(i+1),s) for i,s in enumerate(retries) ]+
               [ ("retry-done%d"%(i+1),s) for i,s in enumerate(retry_done) ]+
               [ ("last-pi6",final_pi) ]):
        if scalar[core["proc_current_slot"]]!=0:
            raise ValueError("slot0 was not servicing last orphan at "+label)
        if word(part,core["proc_high_slot"])!=4:
            raise ValueError("original last-live-slot trim did not reach slot3")
        for slot in (1,2,4,5,6):
            if word(part,expected["table"]+3*slot)!=0:
                raise ValueError("still-live nonquarantined owner at "+label)
        if word(part,expected["table"]+9)!=0o47017600001:
            raise ValueError("last orphan not held at "+label)
        if len(owners)>len(before) or \
           any(o not in before for o in owners) or \
           (raw not in owners or foreign not in owners):
            raise ValueError("nonparent MM leaked or foreign target reclaimed at "+label)
    baseline=orphan[1]
    for i,s in enumerate(retries+retry_done+[final_pi]):
        if s[1]!=baseline:
            raise ValueError("last-child MM ownership changed during idle retry %d"%i)
    delays=[]
    clocks=[]
    for scalar,owners,part in retries:
        pending=word(part,expected["pending"])
        lh=pending>>18
        delay=lh&0o377777
        if (lh&0o400000)==0 or not 0o20<=delay<=0o1000 or \
           (delay&(delay-1))!=0:
            raise ValueError("missing/corrupt original bounded retry backoff")
        delays.append(delay)
        clocks.append(word(part,expected["clock"]))
    if delays!=[0o1000]*3 or [b-a for a,b in
            zip(clocks,clocks[1:])]!=[0o1000,0o1000]:
        raise ValueError("original last-orphan retry cap/clock not exact")
    saved=word(section(trace,"V1911_ORIGINAL_LAST_ORPHAN_PI6",
                       "V1911_STAGE_LAST_PI6"),core["pdp10_pi_level6"])
    if not expected["idle_pc"]<=(saved&0o777777)<core[
            "proc_finish_backoff_advance_v885"]:
        raise ValueError("last-orphan actual PCLK PI6 interrupted outside idle")
    print("PASS v1911: original orphan siblings EXIT slots " +
          ",".join(str(s) for s in slots))
    print("PASS v1911: only slot3 remains; parent and three peers freed")
    print("PASS v1911: exact six peer MM extents retired, no unrelated deletion")
    print("PASS v1911: three real slot0 retries preserve saved child and foreign MM")
    print("PASS v1911: actual idle PI6; no guest HALT/forced child cleanup")
    print("v1911 MM: %d -> %d, retry delays %s (octal)" %
          (parent_gone[0][core["mm_extent_count"]],
           orphan[0][core["mm_extent_count"]],
           ",".join("%04o"%x for x in delays)))


if __name__=="__main__":
    if len(sys.argv)!=4:
        raise SystemExit("usage: verify-physical-v1911.py kit build work")
    try:
        verify(*(Path(a) for a in sys.argv[1:]))
    except (OSError,ValueError,KeyError,AssertionError,UnicodeError) as exc:
        raise SystemExit("FAIL v1911 last-orphan genuine PDP6 test: "+str(exc))
