#!/usr/bin/env python3
"""Strict original PDP-6 permanent foreign-owner idle/retry oracle."""

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
                              "pure-k05-last-orphan-v1911/verify-physical-v1911.py"))
    linked = runpy.run_path(str(kit / "tests/validation/"
                            "pure-k05-secondary-physical-v1845/prepare-v1845.py"))
    read = runpy.run_path(str(kit / "tests/validation/"
                          "pure-k05-foreign-target-v1906/verify-physical-v1906.py"))
    mm = runpy.run_path(str(kit / "tests/diagnostics/"
                        "pure-full-restore-v1638/audit-v1638.py"))
    core = linked["symbols"](build / "kcore.map")
    word = read["word"]
    section = read["section"]
    expected = read["values"](work / "expected-v1913.txt")
    trace = (work / "physical.clean").read_text(encoding="ascii")
    script = (work / "physical.ini").read_text(encoding="ascii")
    original = (work / "physical-v1911.ini").read_text(encoding="ascii")
    if hashlib.sha256((build / "kcore.dxr").read_bytes()).hexdigest() != \
       "a201a7fdcf481b436b06694e5dd55c9367036ebd9f64c630486f854b1a4f89be" or \
       hashlib.sha256((build / "pure-mres-v1612.dxr").read_bytes()).hexdigest() != \
       "09f65d0ca272986b462c63580eae3c4006490004cd060529ce40f10a55949351":
        raise ValueError("original fixed KCORE/PURE images changed")
    if expected != {"extra_retries":12,
                    "retry_pc":core["proc_finish_service_v881"],
                    "idle_pc":core["proc_idle_loop"],
                    "pi6_pc":core["proc_sched_pi_tick"],
                    "clock":core["proc_timer_clock"],
                    "last_retry":core["proc_timer_clock"]+2}:
        raise ValueError("original last-user retry/PI6 symbols drifted")
    footer = "echo V1911_OPERATOR_STOP_NO_CHILD_HALT\nexit\n"
    anchor = "echo V1911_END_LAST_PI6\n"
    if not original.endswith(footer) or script.count(anchor) != 1 or \
       not script.startswith(original[:-len(footer)]) or \
       not script.endswith("echo V1913_OPERATOR_STOP_UNREPAIRED_ORPHAN\nexit\n"):
        raise ValueError("v1911 original last-user controller was not preserved")
    extra = script[len(original)-len(footer):]
    if "deposit " in extra or "V1912_OWNER_REPAIR" in script or \
       script.count("break %06o\n" % expected["retry_pc"]) != 15 or \
       script.count("break %06o\n" % expected["idle_pc"]) != 19 or \
       script.count("break %06o\n" % expected["pi6_pc"]) != 4:
        raise ValueError("foreign owner was repaired or original checkpoints wrong")
    if "HALT instruction" in trace or \
       "V1906_ORIGINAL_TRANSITION_CLEAR" in trace or \
       re.search(r"![A-Za-z0-9]", trace):
        raise ValueError("guest HALT, transition unlock or user fault during quarantine")
    end_old = "V1911_END_LAST_PI6\n"
    if trace.count(end_old) != 1:
        raise ValueError("accepted original v1911 last PI6 stage absent")
    prefix = trace.split(end_old, 1)[0] + end_old + footer
    # Independently reverify the EXACT original pre-extension guest
    # trace, including real exits, three capped retries and PI6.
    with tempfile.TemporaryDirectory(
            dir=os.environ.get("TMPDIR",str(Path.home() / "tmp")),
            prefix="daimos-k05-v1913-prefix-") as directory:
        scratch = Path(directory)
        for name in ("expected-v1902.txt","expected-v1906.txt",
                     "expected-v1907.txt","expected-v1910.txt",
                     "expected-v1911.txt"):
            shutil.copyfile(work / name, scratch / name)
        shutil.copyfile(work / "physical-v1911.ini", scratch / "physical.ini")
        (scratch / "physical.clean").write_text(prefix, encoding="ascii")
        previous["verify"](kit, build, scratch)

    baseline, baseline_owners = mm["stage"](
        trace.replace("V1911_","V1638_"), core, "LAST_PI6")
    root = baseline[core["vfs_namespace_root"]]
    raw = (0o111200,0o120000,4,0,3)
    foreign = (0o120000,0o130000,1,0,2)
    if baseline[core["mm_extent_count"]] != 10 or \
       baseline_owners.count(raw) != 1 or baseline_owners.count(foreign) != 1:
        raise ValueError("original last-orphan MM10 owner set wrong")
    if core["mm_extents"]+2*baseline_owners.index(foreign)+1 != 0o24707:
        raise ValueError("compacted target MM owner address ambiguous")
    clocks = []
    expected_names = []
    for i in range(1,13):
        for name in ("RETRY_%02d" % i,"RETRY_DONE_%02d" % i):
            expected_names.append(name)
        if i in (6,12):
            expected_names.append("PI6_%02d" % i)
    for name in expected_names:
        begin="V1913_STAGE_"+name
        end="V1913_END_"+name
        data, owners = mm["stage"](
            trace.replace("V1913_","V1638_"),core,name)
        part=section(trace,begin,end)
        if data[core["mm_extent_count"]]!=10 or owners!=baseline_owners or \
           data[core["vfs_namespace_root"]]!=root or \
           data[core["proc_current_slot"]]!=0 or \
           word(part,core["proc_high_slot"])!=4 or \
           word(part,0o45711)!=0o47017600001 or \
           word(part,0o45712)!=0o10000000000 or \
           word(part,0o24707)!=0o1000002 or \
           word(part,0o47037)!=0o340000016704 or \
           word(part,0o47043)!=0o4010 or \
           word(part,0o47106)!=0o40000120000:
            raise ValueError("MM/ROOT/orphan/escrow changed at "+name)
        for slot in (1,2,4,5,6):
            if word(part,0o45700+3*slot)!=0:
                raise ValueError("nonorphan user slot resurrected: "+name)
        delayword = word(part,expected["last_retry"])
        if not (delayword&(1<<35)) or \
           ((delayword>>18)&0o377777)!=0o1000:
            raise ValueError("uncertain owner was dropped from capped retry: "+name)
        if name.startswith("RETRY_") and not name.startswith("RETRY_DONE_"):
            clocks.append(word(part,expected["clock"]))
    if len(clocks)!=12 or \
       [b-a for a,b in zip(clocks,clocks[1:])] != [0o1000]*11 or \
       clocks[0]-word(section(trace,"V1911_STAGE_IDLE_RETRY_3",
                             "V1911_END_IDLE_RETRY_3"),expected["clock"])!=0o1000:
        raise ValueError("original 512-tick capped orphan idle cadence broke")
    order = []
    for i in range(1,13):
        for event in ("V1913_REAL_ORPHAN_RETRY_%02d" % i,
                      "V1913_REAL_ORPHAN_RETRY_DONE_%02d" % i):
            if trace.count(event+"\n")!=1:
                raise ValueError("original retry event missing: "+event)
            order.append(trace.index(event+"\n"))
        if i in (6,12):
            event="V1913_ORIGINAL_HELD_PI6_%02d" % i
            if trace.count(event+"\n")!=1:
                raise ValueError("real PI6 event missing: "+event)
            order.append(trace.index(event+"\n"))
            saved=word(section(trace,event,"V1913_STAGE_PI6_%02d" % i),
                       core["pdp10_pi_level6"])
            pc=saved&0o777777
            if not expected["idle_pc"]<=pc<core[
                    "proc_finish_backoff_advance_v885"] or saved&(0o10000<<18):
                raise ValueError("real PI6 did not interrupt original idle")
    if order!=sorted(order) or \
       len(re.findall("Breakpoint, PC: %06o " % expected["retry_pc"],trace))!=15 or \
       len(re.findall("Breakpoint, PC: %06o " % expected["idle_pc"],trace))!=19 or \
       len(re.findall("Breakpoint, PC: %06o " % expected["pi6_pc"],trace))!=4 or \
       trace.count("V1913_OPERATOR_STOP_UNREPAIRED_ORPHAN\n")!=1:
        raise ValueError("native PDP-6 retry/idle/PI6 sequence not genuine")
    print("PASS v1913: original v1911 last-orphan oracle independently rerun")
    print("PASS v1913: 12 additional genuine 512-tick capped idle retries")
    print("PASS v1913: two additional actual PCLK PI6 interrupt original idle")
    print("PASS v1913: exact MM10/ROOT/foreign target/CTX/escrow unchanged")
    print("PASS v1913: no owner repair, forced FINALIZE or native guest HALT")
    print("v1913 retry clock range (octal): %06o -> %06o" %
          (clocks[0],clocks[-1]))


if __name__ == "__main__":
    if len(sys.argv)!=4:
        raise SystemExit("usage: verify-physical-v1913.py kit build work")
    try:
        verify(*(Path(x) for x in sys.argv[1:]))
    except (OSError,ValueError,KeyError,AssertionError,UnicodeError) as exc:
        raise SystemExit("FAIL v1913 persistent terminal orphan: "+str(exc))
