#!/usr/bin/env python3
"""Actual parent EXIT must not reclaim a foreign-owned child FULL target."""

from pathlib import Path
import hashlib
import re
import runpy
import sys


def verify(kit, build, work):
    old = runpy.run_path(str(kit / "tests/validation/"
                         "pure-k05-foreign-target-v1906/verify-physical-v1906.py"))
    base = runpy.run_path(str(kit / "tests/validation/"
                          "pure-k05-secondary-physical-v1845/prepare-v1845.py"))
    mm = runpy.run_path(str(kit / "tests/diagnostics/"
                        "pure-full-restore-v1638/audit-v1638.py"))
    core = base["symbols"](build / "kcore.map")
    user = base["symbols"](build.parent / "user/init.map")
    e = old["values"](work / "expected-v1906.txt")
    v1907 = old["values"](work / "expected-v1907.txt")
    x = old["values"](work / "expected-v1910.txt")
    script = (work / "physical.ini").read_text(encoding="ascii")
    trace = (work / "physical.clean").read_text(encoding="ascii")
    guest = (build.parent / "user/init-v1614.c").read_text(encoding="ascii")
    word = old["word"]
    section = old["section"]
    if hashlib.sha256((build / "kcore.dxr").read_bytes()).hexdigest() != \
       "a201a7fdcf481b436b06694e5dd55c9367036ebd9f64c630486f854b1a4f89be" or \
       hashlib.sha256((build / "pure-mres-v1612.dxr").read_bytes()).hexdigest() != \
       "09f65d0ca272986b462c63580eae3c4006490004cd060529ce40f10a55949351":
        raise ValueError("not the source-identical v1906 fixed KCORE/PURE")
    if x != {"exit_gate":0o130000+user["v1910_exit_gate"],
             "term_gate":0o130000+user["v1907_term_gate"],
             "wait_gate":0o130000+user["v1901_term_gate"],
             "exit_value":0o65432107654,"parent_meta":0o45703,
             "parent_uarea":0o45761,"exit_pc":core["proc_exit_current"],
             "owner_pc":core["proc_finish_slot_owner_v932"],
             "idle_pc":core["proc_idle_loop"],
             "pi6_pc":core["proc_sched_pi_tick"]}:
        raise ValueError("original physical parent EXIT source/map drift")
    if e["process_table"] != 0o45700 or e["uarea"] != 0o47017 or \
       v1907["term_gate"] != x["term_gate"] or \
       v1907["wait_gate"] != x["wait_gate"]:
        raise ValueError("old MM/finalizer fixture not source-linked")
    if guest.count("v1910_exit_gate == 065432107654UL") != 1 or \
       guest.count("rc_v1910 = dsys_exit(0);") != 1 or \
       guest.count("rc_v1910 == 0 ? 'A' : 'R'") != 1 or \
       script.count("deposit %06o %012o\n" %
                    (x["exit_gate"],x["exit_value"])) != 1 or \
       script.count("deposit %06o %012o\n" %
                    (x["term_gate"],v1907["term_value"])) != 1 or \
       script.count('expect "TR"\ncont\n') != 1 or \
       script.count('expect "E"\ncont\n') != 1 or \
       "V1906_FOREIGN_TARGET_REPAIR" in script or \
       "V1906_ORIGINAL_NATIVE_TARGET_FREE_CALL" in script or \
       not script.endswith("echo V1910_OPERATOR_STOP_NO_GUEST_HALT\nexit\n"):
        raise ValueError("not one true parent EXIT with still-foreign target")
    names = ("V1902_REAL_MM_FREE_REFUSED",
             "V1906_FOREIGN_TARGET_INJECT",
             "V1907_ORIGINAL_USER_TERM_REFUSED",
             "V1910_PARENT_EXIT_GATE_BEFORE",
             "V1910_END_PARENT_EXIT_GATE_BEFORE",
             "V1910_PARENT_EXIT_GATE_ARMED",
             "V1910_END_PARENT_EXIT_GATE_ARMED",
             "V1910_REAL_PARENT_USER_EXIT_REQUEST",
             "V1910_ORIGINAL_PARENT_EXIT_CURRENT",
             "V1910_STAGE_EXIT_ENTRY",
             "V1910_END_EXIT_ENTRY",
             "V1910_ORIGINAL_SLOT0_OWNER_FINALIZER",
             "V1910_STAGE_FINALIZER",
             "V1910_END_FINALIZER",
             "V1910_ORIGINAL_PARENT_EXIT_IDLE",
             "V1910_STAGE_PARENT_GONE",
             "V1910_END_PARENT_GONE",
             "V1910_ORIGINAL_POST_EXIT_PI6",
             "V1910_STAGE_POST_EXIT_PI6",
             "V1910_END_POST_EXIT_PI6",
             "V1910_OPERATOR_STOP_NO_GUEST_HALT")
    positions = [trace.find(k+"\n") for k in names]
    if any(p<0 or trace.count(k+"\n")!=1
           for p,k in zip(positions,names)) or positions!=sorted(positions):
        raise ValueError("actual original parent EXIT checkpoints absent/out of order")
    for name in ("exit_pc","owner_pc","idle_pc","pi6_pc"):
        if len(re.findall(r"Breakpoint, PC: %06o " % x[name],trace))!=1:
            raise ValueError("original KCORE checkpoint not reached: "+name)
    if "HALT instruction" in trace or "V1906_ORIGINAL_TRANSITION_CLEAR" in trace or \
       re.search(r"!([0-9a-zA-Z])",trace):
        raise ValueError("test claims false native HALT/transition recovery")
    if word(section(trace,"V1902_REAL_MM_FREE_REFUSED",
                    "V1902_STAGE_NATIVE_REFUSED"),1)!=0o777777777773:
        raise ValueError("native PACKED source free must genuinely return -5")
    if word(section(trace,"V1906_FOREIGN_TARGET_INJECT",
                    "V1906_END_FOREIGN_TARGET_INJECT"),e["target_meta"])!=0o1000003:
        raise ValueError("injection not from genuine original target owner3")
    before = section(trace,"V1910_PARENT_EXIT_GATE_BEFORE",
                     "V1910_END_PARENT_EXIT_GATE_BEFORE")
    armed = section(trace,"V1910_PARENT_EXIT_GATE_ARMED",
                    "V1910_END_PARENT_EXIT_GATE_ARMED")
    if word(before,x["exit_gate"])!=0 or \
       word(armed,x["exit_gate"])!=x["exit_value"] or \
       not re.search(r"TR\s*V1907_ORIGINAL_USER_TERM_REFUSED",trace) or \
       not re.search(r"E\s*V1910_REAL_PARENT_USER_EXIT_REQUEST",trace):
        raise ValueError("original user TERM/EXIT did not physically execute")
    def stage(prefix,name):
        data,owners=mm["stage"](trace.replace(prefix+"_","V1638_"),
                                 core,name)
        block=section(trace,prefix+"_STAGE_"+name,prefix+"_END_"+name)
        return data,owners,block
    term,term_mm,term_block = stage("V1907","TERM_REFUSED")
    entry,entry_mm,entry_block = stage("V1910","EXIT_ENTRY")
    final,final_mm,final_block = stage("V1910","FINALIZER")
    gone,gone_mm,gone_block = stage("V1910","PARENT_GONE")
    pi,pi_mm,pi_block = stage("V1910","POST_EXIT_PI6")
    raw=(0o111200,0o120000,4,0,3)
    target=(0o120000,0o130000,1,0,2)
    for name,data,owners,block in (
            ("TERM",term,term_mm,term_block),
            ("entry",entry,entry_mm,entry_block),
            ("finalizer",final,final_mm,final_block),
            ("parent-gone",gone,gone_mm,gone_block),
            ("post-exit-PI6",pi,pi_mm,pi_block)):
        if owners.count(raw)!=1 or owners.count(target)!=1 or \
           data[core["vfs_namespace_root"]]!=term[core["vfs_namespace_root"]] or \
           word(block,e["uarea"]+0o67)!=(1<<32)|0o120000 or \
           not(word(block,e["process_table"]+9)&(1<<16)) or \
           (word(block,e["process_table"]+10)&0o777777) or \
           word(block,x["wait_gate"])!=0:
            raise ValueError("foreign child MM/escrow/transition lost at "+name)
    for addr in (e["uarea"]+0o20,e["uarea"]+0o24,
                 e["uarea"]+0o67):
        v=word(term_block,addr)
        for name,block in (("entry",entry_block),("final",final_block),
                           ("gone",gone_block),("PI6",pi_block)):
            if word(block,addr)!=v:
                raise ValueError("child saved executive continuation changed: "+name)
    if entry[core["proc_current_slot"]]!=1 or \
       final[core["proc_current_slot"]]!=0 or \
       gone[core["proc_current_slot"]]!=0 or \
       pi[core["proc_current_slot"]]!=0:
        raise ValueError("original parent EXIT did not switch to slot0")
    parent_meta=word(term_block,x["parent_meta"])
    if parent_meta>>18!=x["parent_uarea"] or \
       word(entry_block,x["parent_meta"])!=parent_meta or \
       word(final_block,x["parent_meta"])!=parent_meta|0o200000:
        raise ValueError("real parent uarea missing before native EXIT")
    if word(gone_block,x["parent_meta"])!=0 or \
       word(pi_block,x["parent_meta"])!=0:
        raise ValueError("original parent descriptor not retired after EXIT")
    if gone_mm!=pi_mm or \
       not set((raw,target)).issubset(set(gone_mm)):
        raise ValueError("post-EXIT actual PI6 unexpectedly freed child owner")
    if term[core["mm_extent_count"]]!=18 or \
       gone[core["mm_extent_count"]]!=16 or \
       pi[core["mm_extent_count"]]!=16 or \
       [v for v in term_mm if v not in gone_mm]!=[
         (0o45761,0o46371,3,0,0o1001),
         (0o130000,0o140000,1,0,1)] or \
       [v for v in gone_mm if v not in term_mm]:
        raise ValueError("native parent EXIT freed/changed nonparent MM")
    child_before=word(term_block,e["process_table"]+9)
    child_after=word(gone_block,e["process_table"]+9)
    if (child_before&0o177400)!=0o400 or \
       child_after!=child_before&~0o400 or \
       word(pi_block,e["process_table"]+9)!=child_after:
        raise ValueError("original parent EXIT lost exact orphan adoption")
    pi_saved=word(section(trace,"V1910_ORIGINAL_POST_EXIT_PI6",
                         "V1910_STAGE_POST_EXIT_PI6"),core["pdp10_pi_level6"])
    if pi_saved&(0o10000<<18) or \
       not core["proc_idle_loop"]<=(pi_saved&0o777777)<core[
           "proc_finish_backoff_advance_v885"]:
        raise ValueError("post-parent original PI6 did not interrupt idle")
    print("PASS v1910: genuine parent USER EXIT and fixed-KCORE finalizer")
    print("PASS v1910: parent slot1 retired; unrepaired foreign child remains live")
    print("PASS v1910: full child RAW/target, saved executive CTX and escrow intact")
    print("PASS v1910: original parent MM-only release, child parent1->orphan0")
    print("PASS v1910: original post-EXIT PI6, no fabricated guest HALT")
    print("v1910 MM counts: %d (TERM), %d (parent gone), %d (PI6)" %
          (term[core["mm_extent_count"]],gone[core["mm_extent_count"]],
           pi[core["mm_extent_count"]]))


if __name__=="__main__":
    if len(sys.argv)!=4:
        raise SystemExit("usage: verify-physical-v1910.py kit build work")
    try:
        verify(*(Path(s) for s in sys.argv[1:]))
    except (OSError,ValueError,AssertionError,KeyError,UnicodeError) as exc:
        raise SystemExit("FAIL v1910 original parent EXIT/foreign FULL: "+str(exc))
