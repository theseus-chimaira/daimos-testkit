#!/usr/bin/env python3
"""Execute independently corrupted accepted PDP6 native TERM transcripts."""

from pathlib import Path
import re
import subprocess
import sys


def stage_replace(text, start, end, address, expected, changed):
    begin="V1901_" + start + "\n"
    finish="V1901_" + end + "\n"
    if text.count(begin)!=1 or text.count(finish)!=1:
        raise ValueError("physical stage not unique: " + start)
    prefix,rest=text.split(begin,1)
    body,suffix=rest.split(finish,1)
    old="%o:\t%012o" % (address,expected)
    new="%o:\t%012o" % (address,changed)
    if body.count(old)!=1:
        raise ValueError("physical word/mutation not unique: %06o" % address)
    return prefix+begin+body.replace(old,new,1)+finish+suffix


def word(block,address):
    match=re.findall(r"(?m)^%o:\s*([0-7]{12})\s*$" % address,block)
    if len(match)!=1:
        raise ValueError("physical original value absent/ambiguous %06o"%address)
    return int(match[0],8)


def audit(kit,build,work):
    trace=work/"physical.clean"
    source=trace.read_bytes()
    original=source.decode("ascii")
    env=dict((name,int(v,8)) for name,v in re.findall(
        r"(?m)^([a-z0-9_]+)\s+([0-7]+)$",
        (work/"expected-v1901.txt").read_text("ascii")))
    table=env["table"]
    uarea=env["uarea"]
    gate=env["physical_gate"]
    term=original.split("V1901_STAGE_TERM_REFUSED\n",1)[1].split(
        "V1901_END_TERM_REFUSED\n",1)[0]
    before=original.split("V1901_USER_GATE_BEFORE\n",1)[1].split(
        "V1901_END_USER_GATE_BEFORE\n",1)[0]
    armed=original.split("V1901_USER_GATE_ARMED\n",1)[1].split(
        "V1901_END_USER_GATE_ARMED\n",1)[0]
    source_meta=word(term,0o24703)
    target_meta=word(term,0o24705)
    slotmeta=word(term,table+9)
    pc=word(term,uarea+0o20)
    fdctl=word(term,uarea+0o24)
    finalize=word(term,uarea+0o67)
    if word(before,gate)!=0 or word(armed,gate)!=env["gate_value"]:
        raise ValueError("original v1901 actual user gate witness drifted")
    mutants=(
        ("early-nonzero-user-gate",
         stage_replace(original,"USER_GATE_BEFORE","END_USER_GATE_BEFORE",
             gate,0,env["gate_value"]),
         "original native user TERM was not gated AFTER fault"),
        ("gate-not-armed",
         stage_replace(original,"USER_GATE_ARMED","END_USER_GATE_ARMED",
             gate,env["gate_value"],0),
         "original native user TERM was not gated AFTER fault"),
        ("refused-TERM-falsified-success",
         original.replace("TRV1901_ACTUAL_USER_TERM_REFUSED\n",
                          "TAV1901_ACTUAL_USER_TERM_REFUSED\n",1),
         "original parent did not truly report TERM(3) refusal"),
        ("refused-TERM-cleared-transition",
         stage_replace(original,"STAGE_TERM_REFUSED","END_TERM_REFUSED",
             table+9,slotmeta,slotmeta & ~(1<<16)),
         "original TERM changed quarantined child/MM state"),
        ("refused-TERM-deleted-source-pin",
         stage_replace(original,"STAGE_TERM_REFUSED","END_TERM_REFUSED",
             0o24703,source_meta,source_meta-(1<<21)),
         "refused user TERM changed original MM descriptor"),
        ("refused-TERM-altered-target-pin",
         stage_replace(original,"STAGE_TERM_REFUSED","END_TERM_REFUSED",
             0o24705,target_meta,target_meta+(1<<21)),
         "refused user TERM changed original MM descriptor"),
        ("refused-TERM-created-FINALIZE",
         stage_replace(original,"STAGE_TERM_REFUSED","END_TERM_REFUSED",
             uarea+0o67,finalize,finalize|(1<<35)),
         "original rejected TERM mutated live u-area"),
        ("refused-TERM-altered-FDCTL",
         stage_replace(original,"STAGE_TERM_REFUSED","END_TERM_REFUSED",
             uarea+0o24,fdctl,fdctl^4),
         "original rejected TERM mutated live u-area"),
        ("refused-TERM-changed-context",
         stage_replace(original,"STAGE_TERM_REFUSED","END_TERM_REFUSED",
             uarea+0o20,pc,pc^1),
         "original rejected TERM mutated live u-area"),
    )
    verify=kit/"tests/validation/pure-k05-transition-term-v1901/verify-physical-v1901.py"
    for name,corrupted,error in mutants:
        if corrupted==original:
            raise ValueError("test-only negative mutation was inert: " + name)
        trace.write_text(corrupted,encoding="ascii")
        try:
            result=subprocess.run([sys.executable,str(verify),str(kit),str(build),
                                   str(work)],capture_output=True,text=True)
        finally:
            trace.write_bytes(source)
        if result.returncode==0 or error not in result.stderr:
            raise ValueError("unsafe v1901 %s not rejected at exact oracle: %s" %
                             (name,result.stderr.strip()))
        print("PASS v1901: independently corrupted original physical %s rejected"%name)
    print("PASS v1901: all %d independent original physical TERM gate/owner controls"%
          len(mutants))


if __name__=="__main__":
    if len(sys.argv)!=4:
        raise SystemExit("usage: negative-physical-v1901.py kit build original-work")
    try:
        audit(*(Path(x) for x in sys.argv[1:]))
    except (ValueError,KeyError,OSError,UnicodeError,AssertionError) as e:
        raise SystemExit("FAIL v1901 independent original physical negatives: " + str(e))
