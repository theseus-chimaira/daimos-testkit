#!/usr/bin/env python3
"""Insert a real parent TERM into the v1906 foreign-owner physical trace."""

from pathlib import Path
import re
import runpy
import sys


def prepare(kit, build, probe, work, prefix):
    prior=runpy.run_path(str(kit/"tests/validation/"
                         "pure-k05-foreign-target-v1906/prepare-physical-v1906.py"))
    prior["prepare"](kit,build,probe,work,prefix)
    syms=runpy.run_path(str(kit/"tests/validation/"
                        "pure-k05-secondary-physical-v1845/prepare-v1845.py"))[
                        "symbols"](build.parent/"user/init.map")
    source=(build.parent/"user/init-v1614.c").read_text(encoding="ascii")
    if source.count("v1907_term_gate == 076543210123UL")!=1 or \
            source.count("rc_v1907 == 0 ? 'A' : 'R'")!=1 or \
            source.count("if (v1901_term_gate != 0UL)")!=1:
        raise ValueError("not a unique real parent TERM and final WAIT fixture")
    if "v1907_term_gate" not in syms or "v1901_term_gate" not in syms:
        raise ValueError("actual parent user linked gate symbols missing")
    term_gate=0o130000+syms["v1907_term_gate"]
    old_gate=0o130000+syms["v1901_term_gate"]
    if not 0o130000 < term_gate < 0o140000 or term_gate==old_gate:
        raise ValueError("TERM gate is not isolated parent USER APR")
    path=work/"physical.ini"
    script=path.read_text(encoding="ascii")
    anchor="echo V1906_END_FOREIGN_HELD_HB_1\n"
    first="echo V1906_STAGE_FOREIGN_HELD_HB_1\n"
    if script.count(anchor)!=1 or script.count(first)!=1:
        raise ValueError("first foreign-owner HBs not source unique")
    snap=script.split(first,1)[1].split(anchor,1)[0]
    if "deposit " in snap or "echo " in snap:
        raise ValueError("v1906 physical snapshot not read-only")
    insert=("echo V1907_TERM_GATE_BEFORE\n"+
            "examine %06o\n"%term_gate+
            "echo V1907_END_TERM_GATE_BEFORE\n"+
            "deposit %06o %012o\n"%(term_gate,0o76543210123)+
            "echo V1907_TERM_GATE_ARMED\n"+
            "examine %06o\n"%term_gate+
            "echo V1907_END_TERM_GATE_ARMED\n"+
            "nobreak all\nexpect \"TR\"\ncont\n"+
            "echo V1907_ORIGINAL_USER_TERM_REFUSED\n"+
            "echo V1907_STAGE_TERM_REFUSED\n"+snap+
            "echo V1907_END_TERM_REFUSED\n")
    script=script.replace(anchor,anchor+insert,1)
    if script.count("deposit %06o %012o\n"%(term_gate,0o76543210123))!=1 or \
            script.count('expect "TR"\ncont\n')!=1 or \
            script.count("deposit %06o %012o\n"%(
                old_gate,0o12345670123))!=1:
        raise ValueError("TERM injection would bypass the original WAIT gate")
    path.write_text(script,encoding="ascii")
    (work/"expected-v1907.txt").write_text(
        "term_gate %06o\nwait_gate %06o\nterm_value %012o\n"%
        (term_gate,old_gate,0o76543210123),encoding="ascii")
    print("v1907: real user TERM gate %06o, original typed WAIT gate %06o"%
          (term_gate,old_gate))


if __name__=="__main__":
    if len(sys.argv)!=6:
        raise SystemExit("usage: prepare-physical-v1907.py kit build probe work prefix")
    try:
        prepare(*(Path(s) for s in sys.argv[1:]))
    except (OSError,ValueError,AssertionError,KeyError) as exc:
        raise SystemExit("FAIL v1907 physical preparation: "+str(exc))
