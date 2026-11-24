#!/usr/bin/env python3
"""Verify full last-orphan prefix, lawful late recovery and actual HALT."""

from pathlib import Path
import hashlib
import os
import re
import runpy
import shutil
import tempfile
import sys


def verify(kit,build,work):
    prior=runpy.run_path(str(kit / "tests/validation/"
                          "pure-k05-last-orphan-v1911/verify-physical-v1911.py"))
    linked=runpy.run_path(str(kit / "tests/validation/"
                           "pure-k05-secondary-physical-v1845/prepare-v1845.py"))
    physical=runpy.run_path(str(kit / "tests/validation/"
                          "pure-k05-foreign-target-v1906/verify-physical-v1906.py"))
    audit=runpy.run_path(str(kit / "tests/diagnostics/"
                         "pure-full-restore-v1638/audit-v1638.py"))
    core=linked["symbols"](build / "kcore.map")
    vals=physical["values"]
    word=physical["word"]
    section=physical["section"]
    e=vals(work/"expected-v1906.txt")
    x=vals(work/"expected-v1912.txt")
    trace=(work/"physical.clean").read_text(encoding="ascii")
    script=(work/"physical.ini").read_text(encoding="ascii")
    if hashlib.sha256((build/"kcore.dxr").read_bytes()).hexdigest()!= \
       "a201a7fdcf481b436b06694e5dd55c9367036ebd9f64c630486f854b1a4f89be" or \
       hashlib.sha256((build/"pure-mres-v1612.dxr").read_bytes()).hexdigest()!= \
       "09f65d0ca272986b462c63580eae3c4006490004cd060529ce40f10a55949351":
        raise ValueError("original KCORE/PURE bytes changed")
    if x!={"target_meta":core["mm_extents"]+0o23,
           "target_call":e["target_call"],
           "transition_clear":e["transition_clear"],
           "source_return":e["source_return"],
           "service_return":e["service_return"],
           "child_exit":core["proc_exit_current"],
           "table":e["process_table"],"uarea":e["uarea"]}:
        raise ValueError("late recovery symbol metadata not source-linked")
    if script.count("deposit %06o %012o\n" %
                    (e["target_meta"],0o1000002))!=1 or \
       script.count("deposit %06o %012o\n" %
                    (x["target_meta"],0o1000003))!=1 or \
       "deposit 1 " in script or \
       not script.endswith("echo V1912_END_HALT\nexit\n"):
        raise ValueError("late repair changed kernel responses or HALT path")
    marker="V1912_OWNER_REPAIR_BEFORE\n"
    if trace.count(marker)!=1 or \
       trace.count("V1911_END_LAST_PI6\n")!=1:
        raise ValueError("original last orphan trace prefix not complete")
    prefix=trace.split(marker,1)[0]+"V1911_OPERATOR_STOP_NO_CHILD_HALT\n"
    # Reuse the exact accepted v1911 read-only oracle. The prefix is
    # the SAME physical execution before the late test-owner repair;
    # only the separate physical controller footer is substituted.
    with tempfile.TemporaryDirectory(
            dir=os.environ.get("TMPDIR",str(Path.home()/"tmp")),
            prefix="daimos-k05-v1912-prefix-") as d:
        tmp=Path(d)
        for name in ("expected-v1902.txt","expected-v1906.txt",
                     "expected-v1907.txt","expected-v1910.txt",
                     "expected-v1911.txt"):
            shutil.copyfile(work/name,tmp/name)
        shutil.copyfile(work/"physical-v1911.ini",tmp/"physical.ini")
        (tmp/"physical.clean").write_text(prefix,encoding="ascii")
        prior["verify"](kit,build,tmp)
    print("PASS v1912: complete real last-orphan v1911 prefix verified")

    names=("V1912_OWNER_REPAIR_BEFORE","V1912_OWNER_REPAIR_AFTER",
           "V1912_END_OWNER_REPAIR",
           "V1912_ORIGINAL_NATIVE_TARGET_FREE_CALL",
           "V1912_ORIGINAL_NATIVE_TARGET_FREE_RETURN",
           "V1912_ORIGINAL_TRANSITION_CLEAR",
           "V1912_ORIGINAL_SECOND_SOURCE_FREE_RETURN",
           "V1912_ORIGINAL_SECOND_FULL_SERVICE_RETURN",
           "V1912_ORIGINAL_LAST_CHILD_EXIT",
           "V1912_ORIGINAL_NATIVE_LAST_USER_HALT")
    pos=[trace.find(n+"\n") for n in names]
    if any(p<0 or trace.count(n+"\n")!=1 for p,n in zip(pos,names)) or \
       pos!=sorted(pos):
        raise ValueError("native last-user reconciliation/HALT sequence absent")
    for key in ("target_call","transition_clear","source_return",
                "service_return","child_exit"):
        if len(re.findall(r"Breakpoint, PC: %06o " % x[key],trace))<1:
            raise ValueError("native compiled function never executed: "+key)
    if trace.count("HALT instruction, PC: 000000")!=1 or \
       "HALT instruction, PC: 000001" in trace or \
       "HALT instruction, PC: 000002" in trace or \
       re.search(r"![A-Za-z0-9]",trace):
        raise ValueError("no genuine non-error last-user HALT")
    before_repair=section(trace,"V1912_OWNER_REPAIR_BEFORE",
                          "V1912_OWNER_REPAIR_AFTER")
    after_repair=section(trace,"V1912_OWNER_REPAIR_AFTER",
                         "V1912_END_OWNER_REPAIR")
    if word(before_repair,x["target_meta"])!=0o1000002 or \
       word(after_repair,x["target_meta"])!=0o1000003:
        raise ValueError("last-user compacted target MM owner not exactly repaired")

    def stage(name):
        scalars,owners=audit["stage"](
            trace.replace("V1912_","V1638_"),core,name)
        text=section(trace,"V1912_STAGE_"+name,"V1912_END_"+name)
        return scalars,owners,text

    pre=stage("BEFORE_TARGET_FREE")
    freed=stage("TARGET_FREED")
    unlocked=stage("UNLOCKED")
    raw_return=stage("SOURCE_FREED")
    committed=stage("FULL_COMMITTED")
    child=stage("CHILD_EXIT")
    done=stage("HALT")
    raw=(0o111200,0o120000,4,0,3)
    provisional=(0o120000,0o130000,1,0,3)
    if core["mm_extents"]+2*pre[1].index(provisional)+1!=x["target_meta"]:
        raise ValueError("post-last-user compacted MM index did not match target")
    original_root=pre[0][core["vfs_namespace_root"]]
    if pre[0][core["mm_extent_count"]]!=10 or \
       pre[1].count(raw)!=1 or pre[1].count(provisional)!=1 or \
       word(pre[2],x["uarea"]+0o67)!=0o40000120000 or \
       not(word(pre[2],x["table"]+9)&(1<<16)):
        raise ValueError("original quarantined owner not intact at native free")
    if word(section(trace,"V1912_ORIGINAL_NATIVE_TARGET_FREE_RETURN",
                    "V1912_STAGE_TARGET_FREED"),1)!=0 or \
       freed[0][core["mm_extent_count"]]!=9 or \
       freed[1]!=[v for v in pre[1] if v!=provisional]:
        raise ValueError("original target free did not release only owner3 PROCESS")
    if word(unlocked[2],x["table"]+9)&(1<<16) or \
       word(unlocked[2],x["uarea"]+0o67)!=0 or \
       unlocked[1]!=freed[1]:
        raise ValueError("original escrow cleared before/without safe target release")
    if word(section(trace,"V1912_ORIGINAL_SECOND_SOURCE_FREE_RETURN",
                    "V1912_STAGE_SOURCE_FREED"),1)!=0 or \
       raw in raw_return[1] or \
       any(v==raw for v in committed[1]):
        raise ValueError("original second FULL did not genuinely free source RAW")
    if word(section(trace,"V1912_ORIGINAL_SECOND_FULL_SERVICE_RETURN",
                    "V1912_STAGE_FULL_COMMITTED"),1)!=0 or \
       word(committed[2],x["table"]+9)&(1<<16) or \
       (word(committed[2],x["table"]+10)&0o777777)==0 or \
       not any(typ==1 and owner==3 and pins==0
               for start,end,typ,pins,owner in committed[1]):
        raise ValueError("original FULL did not publish genuine resident child")
    if word(child[2],core["proc_current_slot"])!=3 or \
       word(child[2],x["table"]+9)&(1<<16):
        raise ValueError("real final child SYS_EXIT not reached from slot3")
    if word(done[2],core["proc_current_slot"])!=0 or \
       word(done[2],core["proc_high_slot"])!=1 or \
       done[0][core["mm_extent_count"]]!=6 or \
       any(typ in (1,4) and owner==3 for _,_,typ,_,owner in done[1]) or \
       word(done[2],x["table"]+9)!=0 or \
       word(done[2],x["uarea"]+0o67)!=0:
        raise ValueError("native last-user HALT left child MM, uarea or descriptor")
    for name,tuple_ in (("free",freed),("unlock",unlocked),
                        ("source",raw_return),("commit",committed),
                        ("child",child),("halt",done)):
        if tuple_[0][core["vfs_namespace_root"]]!=original_root:
            raise ValueError("ROOT identity changed during late reconciliation: "+name)
    if "w" not in section(trace,"V1912_ORIGINAL_SECOND_FULL_SERVICE_RETURN",
                          "V1912_ORIGINAL_NATIVE_LAST_USER_HALT"):
        raise ValueError("original last user did not finish pipe read")
    print("PASS v1912: exactly one test-owner repair after last orphan/PI6")
    print("PASS v1912: native target free=0, escrow/TRANSITION retired only after free")
    print("PASS v1912: original second FULL source free=0 and RESIDENT commit")
    print("PASS v1912: original slot3 EXIT, final MM6 and genuine guest HALT")


if __name__=="__main__":
    if len(sys.argv)!=4:
        raise SystemExit("usage: verify-physical-v1912.py kit build work")
    try:
        verify(*(Path(v) for v in sys.argv[1:]))
    except (OSError,ValueError,KeyError,AssertionError,UnicodeError) as exc:
        raise SystemExit("FAIL v1912 real last-user reconcile/HALT: "+str(exc))
