#!/usr/bin/env python3
"""Verify real 17-bit PCLK wrap and retry cadence for unrepaired K05 owner."""

from pathlib import Path
import hashlib
import os
import re
import runpy
import shutil
import sys
import tempfile


def verify(kit, build, work):
    previous = runpy.run_path(str(kit / "tests/validation/"
                              "pure-k05-permanent-orphan-v1913/verify-physical-v1913.py"))
    linked = runpy.run_path(str(kit / "tests/validation/"
                            "pure-k05-secondary-physical-v1845/prepare-v1845.py"))
    read = runpy.run_path(str(kit / "tests/validation/"
                          "pure-k05-foreign-target-v1906/verify-physical-v1906.py"))
    mm = runpy.run_path(str(kit / "tests/diagnostics/"
                        "pure-full-restore-v1638/audit-v1638.py"))
    core = linked["symbols"](build / "kcore.map")
    word, section = read["word"], read["section"]
    expected = read["values"](work / "expected-v1914.txt")
    trace = (work / "physical.clean").read_text(encoding="ascii")
    script = (work / "physical.ini").read_text(encoding="ascii")
    old_script = (work / "physical-v1913.ini").read_text(encoding="ascii")
    clock, epoch = core["proc_timer_clock"],core["proc_timer_clock"]+2
    if expected != {
            "clock":clock, "epoch":epoch,"timer_next":clock+1,
            "pi6_pc":core["proc_sched_pi_tick"],
            "idle_pc":core["proc_idle_loop"],
            "retry_pc":core["proc_finish_service_v881"],
            "rebase_clock":0o377770,"cap":0o1000,"wrap":0o400000,
            "actual_pi6":7,"post_wrap_retries":3}:
        raise ValueError("source-linked original 17-bit timer configuration drift")
    if hashlib.sha256((build / "kcore.dxr").read_bytes()).hexdigest() != \
       "a201a7fdcf481b436b06694e5dd55c9367036ebd9f64c630486f854b1a4f89be" or \
       hashlib.sha256((build / "pure-mres-v1612.dxr").read_bytes()).hexdigest() != \
       "09f65d0ca272986b462c63580eae3c4006490004cd060529ce40f10a55949351":
        raise ValueError("original PDP-6 fixed KCORE/PURE binaries changed")
    footer = "echo V1913_OPERATOR_STOP_UNREPAIRED_ORPHAN\nexit\n"
    if not old_script.endswith(footer) or \
       not script.startswith(old_script[:-len(footer)]) or \
       not script.endswith("echo V1914_OPERATOR_STOP_WITH_FOREIGN_OWNER\nexit\n"):
        raise ValueError("v1913 controller not extended without changes")
    extra = script[len(old_script)-len(footer):]
    if extra.count("deposit ")!=2 or \
       extra.count("deposit %06o %012o\n" % (clock,0o377770))!=1 or \
       extra.count("deposit %06o %012o\n" %
                   (epoch,(0o401000<<18)|0o377770))!=1 or \
       "V1912_OWNER_REPAIR" in script or \
       extra.count("break %06o\n" % expected["pi6_pc"])!=7 or \
       extra.count("break %06o\n" % expected["idle_pc"])!=11 or \
       extra.count("break %06o\n" % expected["retry_pc"])!=3:
        raise ValueError("unapproved clock, MM or instruction controller changes")
    if "HALT instruction" in trace or \
       "V1906_ORIGINAL_TRANSITION_CLEAR" in trace or \
       re.search(r"![A-Za-z0-9]",trace):
        raise ValueError("guest HALT, unsafe unlock or user trap during wrap")

    # Replay the exact physical pre-rebase transcript through the already
    # accepted v1913 oracle (including the full original v1911 prefix).
    end_old = "V1913_END_PI6_12\n"
    if trace.count(end_old)!=1:
        raise ValueError("v1913 native last PI6 boundary missing")
    prefix = trace.split(end_old,1)[0]+end_old+footer
    with tempfile.TemporaryDirectory(
            dir=os.environ.get("TMPDIR",str(Path.home()/"tmp")),
            prefix="daimos-k05-v1914-prefix-") as d:
        tmp = Path(d)
        for name in ("expected-v1902.txt","expected-v1906.txt",
                     "expected-v1907.txt","expected-v1910.txt",
                     "expected-v1911.txt","expected-v1913.txt",
                     "physical-v1911.ini"):
            shutil.copyfile(work/name,tmp/name)
        shutil.copyfile(work/"physical-v1913.ini",tmp/"physical.ini")
        (tmp/"physical.clean").write_text(prefix,encoding="ascii")
        previous["verify"](kit,build,tmp)

    data = trace.replace("V1914_","V1638_")
    ref_scalar, ref_owners = mm["stage"](
        trace.replace("V1913_","V1638_"),core,"PI6_12")
    original_root=ref_scalar[core["vfs_namespace_root"]]
    if ref_scalar[core["mm_extent_count"]]!=10 or \
       ref_owners.count((0o111200,0o120000,4,0,3))!=1 or \
       ref_owners.count((0o120000,0o130000,1,0,2))!=1:
        raise ValueError("original last-orphan exact MM10 owner baseline lost")
    names=["REBASE_BEFORE","REBASE_AFTER","PI6_REBASED_IDLE"]
    for i in range(1,8):
        names.extend(("PI6_BEFORE_%02d"%i,"PI6_DONE_%02d"%i))
    for i in range(1,4):
        names.extend(("POST_WRAP_RETRY_%02d"%i,
                      "POST_WRAP_DONE_%02d"%i))
    stages={}
    for name in names:
        scalar,owners=mm["stage"](data,core,name)
        part=section(trace,"V1914_STAGE_"+name,"V1914_END_"+name)
        if scalar[core["mm_extent_count"]]!=10 or \
           scalar[core["vfs_namespace_root"]]!=original_root or \
           scalar[core["proc_current_slot"]]!=0 or \
           owners!=ref_owners or \
           word(part,core["proc_high_slot"])!=4 or \
           word(part,0o45711)!=0o47017600001 or \
           word(part,0o45712)!=0o10000000000 or \
           word(part,0o24707)!=0o1000002 or \
           word(part,0o47037)!=0o340000016704 or \
           word(part,0o47043)!=0o4010 or \
           word(part,0o47106)!=0o40000120000:
            raise ValueError("last-orphan MM/ROOT/escrow/CTX drift at "+name)
        for slot in (1,2,4,5,6):
            if word(part,0o45700+3*slot)!=0:
                raise ValueError("retired user slot resurrected: "+name)
        stages[name]=(word(part,clock),word(part,epoch),word(part,clock+1))

    old_clock,old_pending,old_timer_next=stages["REBASE_BEFORE"]
    if old_clock!=ref_scalar[clock] or \
       old_pending!=((0o401000<<18)|(old_clock&0o377777)) or \
       old_timer_next!=0:
        raise ValueError("pre-rebase v1913 epoch/delay was not preserved")
    if stages["REBASE_AFTER"] != (0o377770,
                                 ((0o401000<<18)|0o377770),
                                 old_timer_next):
        raise ValueError("clock+epoch synchronized rebase not exact")
    if stages["PI6_REBASED_IDLE"][:2] != (0o377771,
                                           ((0o401000<<18)|0o377770)):
        raise ValueError("last original v1913 PI6 not actually executed")
    for i in range(1,8):
        pre="PI6_BEFORE_%02d" % i
        done="PI6_DONE_%02d" % i
        before,prev_epoch,unused=stages[pre]
        after,after_epoch,unused=stages[done]
        if before!=0o377770+i or after!=before+1 or \
           prev_epoch!=((0o401000<<18)|0o377770) or \
           after_epoch!=prev_epoch:
            raise ValueError("genuine PI6/idle clock failed at wrap step "+str(i))
        label="V1914_REAL_PI6_BEFORE_%02d"%i
        if trace.count(label+"\n")!=1 or \
           trace.count("V1914_REAL_PI6_DONE_%02d\n"%i)!=1:
            raise ValueError("source-linked real PCLK/idle checkpoint absent")
        saved=word(section(trace,label,"V1914_STAGE_"+pre),
                   core["pdp10_pi_level6"])
        if not expected["idle_pc"]<=(saved&0o777777)<core[
                "proc_finish_backoff_advance_v885"]:
            raise ValueError("PCLK interrupted outside the original slot0 idle")
    if stages["PI6_BEFORE_07"][0]!=0o377777 or \
       stages["PI6_DONE_07"][0]!=0o400000 or \
       (stages["PI6_DONE_07"][0]&0o377777)!=0:
        raise ValueError("actual 17-bit masked clock wrap not observed")
    for i in range(1,4):
        pre="POST_WRAP_RETRY_%02d"%i
        done="POST_WRAP_DONE_%02d"%i
        pclk,pending,unused=stages[pre]
        done_clk,done_pending,unused=stages[done]
        want=0o377770+i*0o1000
        if pclk!=want or done_clk!=want or \
           pending!=((0o401000<<18)|(want&0o377777)) or \
           done_pending!=pending:
            raise ValueError("post-wrap clock/epoch/backoff was not 512 ticks")
    if len(re.findall(r"Breakpoint, PC: %06o " % expected["retry_pc"],trace))!=18 or \
       len(re.findall(r"Breakpoint, PC: %06o " % expected["pi6_pc"],trace))!=11 or \
       len(re.findall(r"Breakpoint, PC: %06o " % expected["idle_pc"],trace))!=30 or \
       trace.count("V1914_OPERATOR_STOP_WITH_FOREIGN_OWNER\n")!=1:
        raise ValueError("native original PCLK/idle/retry instruction gates missing")
    print("PASS v1914: independent v1913 and v1911 native physical prefix oracles")
    print("PASS v1914: only original timer/epoch rebased; MM/exec unchanged")
    print("PASS v1914: seven distinct original PCLK/idle steps cross 0377777->0400000")
    print("PASS v1914: three original post-wrap 01000-tick capped retries")
    print("PASS v1914: last orphan MM10/foreign owner/escrow/ROOT held; no guest HALT")


if __name__=="__main__":
    if len(sys.argv)!=4:
        raise SystemExit("usage: verify-physical-v1914.py kit build work")
    try:
        verify(*(Path(s) for s in sys.argv[1:]))
    except (OSError,ValueError,KeyError,AssertionError,UnicodeError) as exc:
        raise SystemExit("FAIL v1914 original clock wrap: "+str(exc))
