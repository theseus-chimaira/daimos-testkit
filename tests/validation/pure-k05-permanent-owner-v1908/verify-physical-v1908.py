#!/usr/bin/env python3
"""Verify bounded real PDP-6 observation of an unrepairable FULL owner."""

from pathlib import Path
import hashlib
import re
import runpy
import sys


def verify(kit, build, work):
    prior=runpy.run_path(str(kit/"tests/validation/"
                         "pure-k05-foreign-target-v1906/verify-physical-v1906.py"))
    base=runpy.run_path(str(kit/"tests/validation/"
                        "pure-k05-secondary-physical-v1845/prepare-v1845.py"))
    mm=runpy.run_path(str(kit/"tests/diagnostics/"
                      "pure-full-restore-v1638/audit-v1638.py"))
    core=base["symbols"](build/"kcore.map")
    user=base["symbols"](build.parent/"user/init.map")
    e=prior["values"](work/"expected-v1906.txt")
    gate=prior["values"](work/"expected-v1907.txt")
    long=prior["values"](work/"expected-v1908.txt")
    trace=(work/"physical.clean").read_text(encoding="ascii")
    script=(work/"physical.ini").read_text(encoding="ascii")
    guest=(build.parent/"user/init-v1614.c").read_text(encoding="ascii")
    section=prior["section"]
    word=prior["word"]
    if long != {"heartbeat_count":10,"max_backoff":0o1000,
                "source_base":0o111200,"target_base":0o120000}:
        raise ValueError("unexpected fixed 10-HB physical observation scope")
    if hashlib.sha256((build/"kcore.dxr").read_bytes()).hexdigest()!= \
       "a201a7fdcf481b436b06694e5dd55c9367036ebd9f64c630486f854b1a4f89be" or \
       hashlib.sha256((build/"pure-mres-v1612.dxr").read_bytes()).hexdigest()!= \
       "09f65d0ca272986b462c63580eae3c4006490004cd060529ce40f10a55949351":
        raise ValueError("KCORE/PURE differ from original accepted v1906/v1907")
    if gate["term_gate"]!=0o130000+user["v1907_term_gate"] or \
       gate["wait_gate"]!=e["parent_gate"] or \
       gate["term_value"]!=0o76543210123 or \
       guest.count("v1907_term_gate == 076543210123UL")!=1 or \
       guest.count("rc_v1907 == 0 ? 'A' : 'R'")!=1:
        raise ValueError("original real source-built parent TERM gate drift")
    if e["target_meta"]!=core["mm_extents"]+0o41 or \
       e["source_meta"]!=core["mm_extents"]+0o37:
        raise ValueError("source-linked MM target descriptor addresses drift")
    if script.count("deposit %06o %012o\n" %
                    (e["target_meta"],0o1000002))!=1 or \
       "deposit %06o %012o\n"%(e["target_meta"],0o1000003) in script or \
       script.count("deposit %06o %012o\n" %
                    (gate["term_gate"],gate["term_value"]))!=1 or \
       "deposit %06o %012o\n"%(e["parent_gate"],0o12345670123) in script:
        raise ValueError("physical controller falsely repaired or released owner")
    after_inject=script.split("echo V1906_END_FOREIGN_TARGET_INJECT\n",1)
    if len(after_inject)!=2 or \
       len(re.findall(r"(?m)^deposit ",after_inject[1]))!=1 or \
       script.count('expect "TR"\ncont\n')!=1 or \
       script.count('expect "HB"\ncont\n')!=11 or \
       "V1906_ORIGINAL_NATIVE_TARGET_FREE_CALL" in script or \
       "V1906_FOREIGN_TARGET_REPAIR" in script or \
       "V1906_ORIGINAL_NATIVE_HALT" in script:
        raise ValueError("uncontrolled terminal/full repair or missing HBs")
    if not script.endswith("echo V1908_OPERATOR_STOP_NO_GUEST_HALT\nexit\n"):
        raise ValueError("simulator stop must be explicitly nonterminal")
    markers=("V1902_REAL_MM_FREE_REFUSED",
             "V1902_ORIGINAL_FAILED_FULL_RETURN",
             "V1902_EXTERNAL_PIN_RELEASE",
             "V1906_FOREIGN_TARGET_INJECT",
             "V1906_END_FOREIGN_TARGET_INJECT",
             "V1906_FOREIGN_HELD_HB_1",
             "V1907_TERM_GATE_BEFORE",
             "V1907_END_TERM_GATE_BEFORE",
             "V1907_TERM_GATE_ARMED",
             "V1907_END_TERM_GATE_ARMED",
             "V1907_ORIGINAL_USER_TERM_REFUSED",
             "V1907_END_TERM_REFUSED",
             "V1906_FOREIGN_HELD_HB_2",
             "V1906_FOREIGN_HELD_HB_3")
    for i in range(4,11):
        markers+=("V1908_LONG_HELD_HB_%d"%i,
                  "V1908_END_LONG_HELD_HB_%d"%i)
    markers+=("V1908_OPERATOR_STOP_NO_GUEST_HALT",)
    positions=[trace.find(x+"\n") for x in markers]
    if any(pos<0 or trace.count(m+"\n")!=1 for pos,m in zip(positions,markers)) or \
       positions!=sorted(positions):
        raise ValueError("original fail-closed/TERM/10-HB order absent")
    if "HALT instruction, PC:" in trace or \
       "V1906_ORIGINAL_TRANSITION_CLEAR" in trace or \
       "V1906_ORIGINAL_PARENT_TYPED_WAIT_Z" in trace:
        raise ValueError("operator observation falsely claims native guest EXIT/HALT")
    if word(section(trace,"V1902_REAL_MM_FREE_REFUSED",
                    "V1902_STAGE_NATIVE_REFUSED"),1)!=0o777777777773:
        raise ValueError("first native PACKED source free not genuine -5")
    original=section(trace,"V1906_FOREIGN_TARGET_INJECT",
                     "V1906_END_FOREIGN_TARGET_INJECT")
    if word(original,e["target_meta"])!=0o1000003:
        raise ValueError("test did not find original slot3 MM target before retag")
    before=section(trace,"V1907_TERM_GATE_BEFORE",
                   "V1907_END_TERM_GATE_BEFORE")
    armed=section(trace,"V1907_TERM_GATE_ARMED",
                  "V1907_END_TERM_GATE_ARMED")
    term=section(trace,"V1907_STAGE_TERM_REFUSED",
                 "V1907_END_TERM_REFUSED")
    if word(before,gate["term_gate"])!=0 or \
       word(armed,gate["term_gate"])!=gate["term_value"] or \
       not re.search(r"TR\s*V1907_ORIGINAL_USER_TERM_REFUSED",trace):
        raise ValueError("real original user TERM not refused during quarantine")

    # All original MM descriptors, not just target and source, must
    # remain byte-equivalent under the permanently foreign owner.
    pinned,prior_ext=mm["stage"](trace.replace("V1902_","V1638_"),
                                 core,"PINNED_HB")
    source_pin1=(0o111200,0o120000,4,1,3)
    source_pin0=(0o111200,0o120000,4,0,3)
    target_slot3=(0o120000,0o130000,1,0,3)
    target_foreign=(0o120000,0o130000,1,0,2)
    if prior_ext.count(source_pin1)!=1 or prior_ext.count(target_slot3)!=1:
        raise ValueError("not an original source-built dual MM owner")
    wanted=[source_pin0 if x==source_pin1 else
            target_foreign if x==target_slot3 else x for x in prior_ext]
    root=pinned[core["vfs_namespace_root"]]
    baseline=None
    clocks=[]
    delays=[]
    epochs=[]

    def capture(prefix,name):
        scalars,owners=mm["stage"](
            trace.replace(prefix+"_","V1638_"),core,name)
        block=section(trace,prefix+"_STAGE_"+name,prefix+"_END_"+name)
        return scalars,owners,block

    for i in range(1,11):
        if i<=3:
            prefix,name="V1906","FOREIGN_HELD_HB_%d"%i
        else:
            prefix,name="V1908","LONG_HELD_HB_%d"%i
        data,owners,block=capture(prefix,name)
        if owners!=wanted or data[core["mm_extent_count"]]!=18 or \
           data[core["proc_current_slot"]]!=1 or \
           data[core["vfs_namespace_root"]]!=root or \
           word(block,core["proc_table"])!=e["process_table"] or \
           (word(block,e["process_table"]+9)>>18)!=e["uarea"] or \
           not (word(block,e["process_table"]+9)&(1<<16)) or \
           (word(block,e["process_table"]+10)&0o777777) or \
           word(block,e["parent_gate"])!=0:
            raise ValueError("original MM/parent/TRANSITION lost at HB%d"%i)
        ctx=(word(block,e["uarea"]+0o20),
             word(block,e["uarea"]+0o24),
             word(block,e["uarea"]+0o67),
             word(block,e["process_table"]+11))
        if baseline is None:
            baseline=ctx
            if ((ctx[0]>>18)&0o10000) or \
               ctx[2]!=(1<<32)|0o120000:
                raise ValueError("original private executive stack/escrow absent")
        if ctx!=baseline:
            raise ValueError("original saved executive context changed HB%d"%i)
        tick=word(block,core["proc_timer_clock"])
        shared=word(block,core["proc_timer_clock"]+2)
        interval=(shared>>18)&0o377777
        if not shared&(1<<35) or interval==0 or interval>0o1000 or \
           (interval & (interval-1)):
            raise ValueError("bounded slot0 retry missing/invalid at HB%d"%i)
        clocks.append(tick)
        delays.append(interval)
        epochs.append(shared&0o777777)
    if clocks!=sorted(set(clocks)) or \
       any(delays[i]>delays[i+1] for i in range(9)) or \
       delays[-1]!=0o1000 or delays[-2]!=0o1000 or \
       not any(epochs[i]==epochs[i+1] for i in range(9)) or \
       epochs[-1]>clocks[-1]:
        raise ValueError("retry not capped/stable or actual parent PCLK stalled")
    term_data,term_owners,term_block=capture("V1907","TERM_REFUSED")
    if term_owners!=wanted or term_data[core["mm_extent_count"]]!=18 or \
       term_data[core["vfs_namespace_root"]]!=root or \
       tuple(word(term_block,a) for a in
             (e["uarea"]+0o20,e["uarea"]+0o24,
              e["uarea"]+0o67,e["process_table"]+11))!=baseline or \
       not word(term_block,e["process_table"]+9)&(1<<16):
        raise ValueError("original refused TERM corrupted foreign owner/ctx")
    print("PASS v1908: real failed PACKED source free -5 and native TERM refused")
    print("PASS v1908: 10 resident parent HBs, MM18 and unchanged foreign target")
    print("PASS v1908: saved exec CTX/FDCTL, escrow 120000, TRANSITION held")
    print("PASS v1908: shared slot0 backoff reaches/holds 01000 ticks")
    print("PASS v1908: no native recovery/exit/HALT claimed; operator stops")
    print("v1908 PCLK first/last: %06o -> %06o"%(clocks[0],clocks[-1]))
    print("v1908 delays: "+" ".join("%04o"%x for x in delays))


if __name__=="__main__":
    if len(sys.argv)!=4:
        raise SystemExit("usage: verify-physical-v1908.py kit build work")
    try:
        verify(*(Path(s) for s in sys.argv[1:]))
    except (OSError,ValueError,KeyError,AssertionError,UnicodeError) as exc:
        raise SystemExit("FAIL v1908 original long-held owner physical: "+str(exc))
