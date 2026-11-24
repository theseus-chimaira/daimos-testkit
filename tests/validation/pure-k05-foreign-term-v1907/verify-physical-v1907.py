#!/usr/bin/env python3
"""One real user TERM must refuse without disturbing escrowed FULL recovery."""

from pathlib import Path
import re
import runpy
import sys


def verify(kit,build,work):
    prior=runpy.run_path(str(kit/"tests/validation/"
                         "pure-k05-foreign-target-v1906/verify-physical-v1906.py"))
    prior["verify"](kit,build,work)
    e=prior["values"](work/"expected-v1907.txt")
    old=prior["values"](work/"expected-v1906.txt")
    trace=(work/"physical.clean").read_text(encoding="ascii")
    script=(work/"physical.ini").read_text(encoding="ascii")
    guest=(build.parent/"user/init-v1614.c").read_text(encoding="ascii")
    base=runpy.run_path(str(kit/"tests/validation/"
                        "pure-k05-secondary-physical-v1845/prepare-v1845.py"))
    mm=runpy.run_path(str(kit/"tests/diagnostics/"
                      "pure-full-restore-v1638/audit-v1638.py"))
    core=base["symbols"](build/"kcore.map")
    user=base["symbols"](build.parent/"user/init.map")
    if e["term_gate"]!=0o130000+user["v1907_term_gate"] or \
            e["wait_gate"]!=old["parent_gate"] or \
            e["term_value"]!=0o76543210123 or \
            script.count("deposit %06o %012o\n"%
                         (e["term_gate"],e["term_value"]))!=1 or \
            guest.count("v1907_term_gate == 076543210123UL")!=1 or \
            guest.count("rc_v1907 == 0 ? 'A' : 'R'")!=1 or \
            guest.count("SYS_EVENT_ARG(3U, SYS_EVENT_TERM)")!=2:
        raise ValueError("source-linked real user TERM fixture not exact")
    labels=("V1906_END_FOREIGN_HELD_HB_1",
            "V1907_TERM_GATE_BEFORE","V1907_END_TERM_GATE_BEFORE",
            "V1907_TERM_GATE_ARMED","V1907_END_TERM_GATE_ARMED",
            "V1907_ORIGINAL_USER_TERM_REFUSED",
            "V1907_STAGE_TERM_REFUSED","V1907_END_TERM_REFUSED",
            "V1906_FOREIGN_HELD_HB_2")
    marks=[s+"\n" for s in labels]
    if any(trace.count(s)!=1 for s in marks) or \
            [trace.index(s) for s in marks]!=sorted(trace.index(s) for s in marks):
        raise ValueError("real TERM not placed within foreign-owner interval")
    before=prior["section"](trace,"V1907_TERM_GATE_BEFORE",
                            "V1907_END_TERM_GATE_BEFORE")
    armed=prior["section"](trace,"V1907_TERM_GATE_ARMED",
                           "V1907_END_TERM_GATE_ARMED")
    term=prior["section"](trace,"V1907_STAGE_TERM_REFUSED",
                          "V1907_END_TERM_REFUSED")
    if prior["word"](before,e["term_gate"])!=0 or \
            prior["word"](armed,e["term_gate"])!=e["term_value"] or \
            not re.search(r"TR\s*V1907_ORIGINAL_USER_TERM_REFUSED",trace) or \
            "TA" in trace.split("V1907_END_TERM_GATE_ARMED\n",1)[1].split(
                "V1907_STAGE_TERM_REFUSED",1)[0]:
        raise ValueError("original TERM syscall not genuinely refused")
    mm_data,owners=mm["stage"](trace.replace("V1907_","V1638_"),
                               core,"TERM_REFUSED")
    hb1=prior["section"](trace,"V1906_STAGE_FOREIGN_HELD_HB_1",
                         "V1906_END_FOREIGN_HELD_HB_1")
    mm_first,owners_first=mm["stage"](
        trace.replace("V1906_","V1638_"),core,"FOREIGN_HELD_HB_1")
    if owners!=owners_first or mm_data[core["mm_extent_count"]]!=18 or \
            mm_data[core["proc_current_slot"]]!=1 or \
            mm_data[core["vfs_namespace_root"]]!=\
            mm_first[core["vfs_namespace_root"]] or \
            prior["word"](term,e["wait_gate"])!=0:
        raise ValueError("real rejected TERM changed process/MM/root or WAIT gate")
    for addr in (old["process_table"]+9,old["process_table"]+10,
                 old["process_table"]+11,old["uarea"]+0o20,
                 old["uarea"]+0o24,old["uarea"]+0o67):
        if prior["word"](term,addr)!=prior["word"](hb1,addr):
            raise ValueError("TERM corrupted saved private state %06o"%addr)
    if prior["word"](term,old["uarea"]+0o67)!=(1<<32)|0o120000 or \
            not (prior["word"](term,old["process_table"]+9)&(1<<16)):
        raise ValueError("real TERM bypassed LIVE FULL escrow/quarantine")
    print("PASS v1907: genuine parent TERM(3) refused under foreign MM owner")
    print("PASS v1907: MM18, target escrow, private CTX/FDCTL and WAIT preserved")
    print("PASS v1907: after owner repair original FULL, five WAIT and HALT")


if __name__=="__main__":
    if len(sys.argv)!=4:
        raise SystemExit("usage: verify-physical-v1907.py kit build work")
    try:
        verify(*(Path(s) for s in sys.argv[1:]))
    except (OSError,ValueError,KeyError,AssertionError) as exc:
        raise SystemExit("FAIL v1907 physical TERM/escrow: "+str(exc))
