#!/usr/bin/env python3
"""Audit real PDP-6 user-mode TERM refusal on pinned TRANSITION child."""

from pathlib import Path
import hashlib
import re
import runpy
import sys


def segment(trace, a, b):
    a += "\n"
    b += "\n"
    if trace.count(a) != 1 or trace.count(b) != 1:
        raise ValueError("missing unique actual physical stage: " + a.strip())
    return trace.split(a,1)[1].split(b,1)[0]


def word(text, address):
    vals=re.findall(r"(?m)^%o:\s*([0-7]{12})\s*$" % address,text)
    if len(vals) != 1:
        raise ValueError("physical stage word absent/ambiguous: %06o" % address)
    return int(vals[0],8)


def verify(kit, build, work):
    previous = runpy.run_path(str(kit/"tests/validation/"
          "pure-k05-terminal-dual-owner-v1900/verify-physical-v1900.py"))
    previous["verify"](kit,build,work)
    trace = (work/"physical.clean").read_text(encoding="ascii")
    guest = (build.parent/"user/init-v1614.c").read_text(encoding="ascii")
    for snippet in ("SYS_PROCCTL_EVENT_PID", "SYS_EVENT_ARG(3U, SYS_EVENT_TERM)",
                    "(void)p14_char(rc_v1901 == 0 ? 'A' : 'R')"):
        if guest.count(snippet) != 1:
            raise ValueError("not original physical native parent TERM(3) source")
    fields = dict((name,int(value,8)) for name,value in re.findall(
        r"(?m)^([a-z0-9_]+)\s+([0-7]+)$",
        (work/"expected-v1901.txt").read_text(encoding="ascii")))
    table=fields["table"]
    uarea=fields["uarea"]
    gate=fields["physical_gate"]
    if fields["parent_base"] != 0o130000 or \
            not fields["parent_base"] < gate < fields["parent_base"]+0o10000:
        raise ValueError("test-only TERM gate is not resident parent user RAM")
    gate_before=segment(trace,"V1901_USER_GATE_BEFORE",
                         "V1901_END_USER_GATE_BEFORE")
    gate_armed=segment(trace,"V1901_USER_GATE_ARMED",
                        "V1901_END_USER_GATE_ARMED")
    if word(gate_before,gate) != 0 or \
            word(gate_armed,gate) != fields["gate_value"]:
        raise ValueError("original native user TERM was not gated AFTER fault")
    first=segment(trace,"V1895_STAGE_HEARTBEAT_1","V1895_END_HEARTBEAT_1")
    before=segment(trace,"V1901_PRETERM_CONTEXT","V1901_END_PRETERM_CONTEXT")
    term=segment(trace,"V1901_STAGE_TERM_REFUSED","V1901_END_TERM_REFUSED")
    last=segment(trace,"V1895_STAGE_HEARTBEAT_2","V1895_END_HEARTBEAT_2")
    if trace.count("V1901_ACTUAL_USER_TERM_REFUSED\n") != 1 or \
            not re.search(r"TR\s*V1901_ACTUAL_USER_TERM_REFUSED",trace):
        raise ValueError("original parent did not truly report TERM(3) refusal")
    if not (trace.index("V1895_END_HEARTBEAT_1\n") <
            trace.index("V1901_USER_GATE_BEFORE\n") <
            trace.index("V1901_USER_GATE_ARMED\n") <
            trace.index("V1901_ACTUAL_USER_TERM_REFUSED\n") <
            trace.index("V1895_ACTUAL_RESIDENT_HEARTBEAT_2\n")):
        raise ValueError("TERM(3) not sent between actual resident user HBs")
    if word(term,table+9) != word(first,table+9) or \
            word(term,table+9) != word(last,table+9) or \
            word(term,table+10) != word(first,table+10) or \
            word(term,table+10) != word(last,table+10) or \
            word(term,table+11) != word(first,table+11):
        raise ValueError("original TERM changed quarantined child/MM state")
    if word(term,table+9)>>18 != uarea or \
            (word(term,table+9)&(1<<16)) == 0 or \
            (word(term,table+10)&0o777777) != 0:
        raise ValueError("TERM target not original nonrunnable TRANSITION owner")
    if (word(term,table+11)>>18)&0o60000:
        raise ValueError("physically held child has unaccounted scheduler WAIT")
    for off in (0o20,0o24,0o67):
        addr=uarea+off
        if word(term,addr)!=word(before,addr):
            raise ValueError("original rejected TERM mutated live u-area %06o" % addr)
    if word(term,uarea+0o67)&(1<<35):
        raise ValueError("TERM refused but illegal FINALIZE was published")
    core=runpy.run_path(str(kit/"tests/validation/"
       "pure-k05-secondary-physical-v1845/prepare-v1845.py"))["symbols"](
           build/"kcore.map")
    if word(term,core["proc_current_slot"])!=1 or \
            word(term,core["proc_table"])!=table or \
            word(term,core["mm_extent_count"])!=18:
        raise ValueError("TERM did not execute in live resident parent")
    for addr in range(core["mm_extents"],core["mm_extents"]+36):
        # The first 18 original packed MM records are immutable during
        # true refused TERM (a simulator-induced free is not accepted).
        if word(term,addr)!=word(first,addr):
            raise ValueError("refused user TERM changed original MM descriptor %06o"%addr)
    pc=word(term,uarea+0o20)
    fdctl=word(term,uarea+0o24)
    final=word(term,uarea+0o67)
    user_pc=(pc>>18)&0o10000
    print("PASS v1901: ACTUAL original user SYS_PROCCTL TERM(3) returns refused")
    print("v1901: TRANSITION retained, MM18 exact conserved, parent HB/PCLK progressed")
    print("v1901: saved PC=%012o user-return-bit=%s" %
        (pc,"set" if user_pc else "clear"))
    print("v1901: FDCTL=%012o FINALIZE=%012o; no premature release" %
        (fdctl,final))
    print("K05 OPEN: foreign fatal on terminally quarantined owner is not yet delivered")


if __name__ == "__main__":
    if len(sys.argv)!=4:
        raise SystemExit("usage: verify-physical-v1901.py kit source-build physical-work")
    try:
        verify(*(Path(a) for a in sys.argv[1:]))
    except (ValueError,KeyError,OSError,UnicodeError,AssertionError) as e:
        raise SystemExit("FAIL v1901 original physical TERM admission: " + str(e))
