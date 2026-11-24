#!/usr/bin/env python3
"""After v1911 last-orphan proof, lawfully reconcile and naturally HALT."""

from pathlib import Path
import os
import runpy
import shutil
import sys


def prepare(kit, build, probe, work, prefix):
    old=runpy.run_path(str(kit / "tests/validation/"
                         "pure-k05-last-orphan-v1911/prepare-physical-v1911.py"))
    old["prepare"](kit,build,probe,work,prefix)
    link=runpy.run_path(str(kit / "tests/validation/"
                         "pure-k05-secondary-physical-v1845/prepare-v1845.py"))
    core=link["symbols"](build / "kcore.map")
    read=runpy.run_path(str(kit / "tests/validation/"
                         "pure-k05-foreign-target-v1906/verify-physical-v1906.py"))
    audit=runpy.run_path(str(kit / "tests/diagnostics/"
                          "pure-full-restore-v1638/audit-v1638.py"))
    expected=read["values"](work / "expected-v1906.txt")
    for key in ("target_meta","target_call","transition_clear",
                "source_return","service_return","process_table","uarea"):
        if key not in expected:
            raise ValueError("original v1906 owner recovery symbol missing: "+key)
    if expected["target_meta"]!=core["mm_extents"]+0o41 or \
       expected["target_call"]!=0o33420 or \
       expected["transition_clear"]!=0o33456:
        raise ValueError("original fixed KCORE/PURE target source changed")
    # IMPORTANT: MM descriptors are compacted as slots 4/5/6 EXIT.
    # The original v1906 injection uses the old index, but repairing
    # THAT index after last-user teardown corrupts a DIFFERENT owner.
    # Resolve the original target by exact geometry in an independently
    # accepted same-build v1911 post-orphan physical trace. Verify the
    # new run's live MM table at the repair checkpoint before acceptance.
    baseline=Path(os.environ.get("V1912_BASELINE_WORK",
                    os.environ.get("TMPDIR",str(Path.home()/"tmp"))+
                    "/daimos-k05-last-orphan-v1911-physical-v2"))
    original=(baseline/"physical.clean").read_text(encoding="ascii")
    facts,extents=audit["stage"](
        original.replace("V1911_","V1638_"),core,"LAST_PI6")
    target=(0o120000,0o130000,1,0,2)
    if facts[core["mm_extent_count"]]!=10 or \
       extents.count(target)!=1 or \
       extents.count((0o111200,0o120000,4,0,3))!=1:
        raise ValueError("accepted v1911 foreign target MM10 not unique")
    target_meta=core["mm_extents"]+2*extents.index(target)+1
    if target_meta==expected["target_meta"] or \
       target_meta!=0o24707:
        raise ValueError("compacted physical target owner index drifted")
    path=work/"physical.ini"
    script=path.read_text(encoding="ascii")
    end="echo V1911_OPERATOR_STOP_NO_CHILD_HALT\nexit\n"
    if not script.endswith(end) or script.count(end)!=1:
        raise ValueError("v1911 late last orphan breakpoint drifted")
    shutil.copyfile(path,work/"physical-v1911.ini")
    start="echo V1911_STAGE_LAST_PI6\n"
    finish="echo V1911_END_LAST_PI6\n"
    if script.count(start)!=1 or script.count(finish)!=1:
        raise ValueError("original post-orphan MM10 snapshot not unique")
    snap=script.split(start,1)[1].split(finish,1)[0]
    if not snap.startswith("examine ") or any(
            not s.startswith("examine ") for s in snap.splitlines()):
        raise ValueError("original v1911 snapshot is not read-only")

    def witness(name):
        return "echo V1912_STAGE_%s\n" % name+snap+ \
               "echo V1912_END_%s\n" % name

    # Only undo the test-created foreign ownership mutation. All child
    # cleanup must then come from original source-linked KCORE/PURE.
    new=("echo V1912_OWNER_REPAIR_BEFORE\n"
         "examine %06o\n" % target_meta +
         "deposit %06o %012o\n" %
         (target_meta,0o1000003) +
         "echo V1912_OWNER_REPAIR_AFTER\n"
         "examine %06o\n" % target_meta +
         "echo V1912_END_OWNER_REPAIR\n" +
         "nobreak all\nbreak %06o\ncont\n" % expected["target_call"] +
         "echo V1912_ORIGINAL_NATIVE_TARGET_FREE_CALL\n" +
         witness("BEFORE_TARGET_FREE") +
         "nobreak all\nbreak %06o\ncont\n" %
         (expected["target_call"]+1) +
         "echo V1912_ORIGINAL_NATIVE_TARGET_FREE_RETURN\nexamine 1\n" +
         witness("TARGET_FREED") +
         "nobreak all\nbreak %06o\ncont\n" %
         expected["transition_clear"] +
         "echo V1912_ORIGINAL_TRANSITION_CLEAR\n" +
         witness("UNLOCKED") +
         "nobreak all\nbreak %06o\ncont\n" %
         expected["source_return"] +
         "echo V1912_ORIGINAL_SECOND_SOURCE_FREE_RETURN\nexamine 1\n" +
         witness("SOURCE_FREED") +
         "nobreak all\nbreak %06o\ncont\n" %
         expected["service_return"] +
         "echo V1912_ORIGINAL_SECOND_FULL_SERVICE_RETURN\nexamine 1\n" +
         witness("FULL_COMMITTED") +
         "nobreak all\nbreak %06o\ncont\n" % core["proc_exit_current"] +
         "echo V1912_ORIGINAL_LAST_CHILD_EXIT\n" +
         witness("CHILD_EXIT") +
         "nobreak all\ncont\n" +
         "echo V1912_ORIGINAL_NATIVE_LAST_USER_HALT\n" +
         witness("HALT") + "exit\n")
    script=script[:-len(end)]+new
    if script.count("deposit %06o %012o\n" %
                    (expected["target_meta"],0o1000002))!=1 or \
       script.count("deposit %06o %012o\n" %
                    (target_meta,0o1000003))!=1 or \
       script.count("V1912_ORIGINAL_LAST_CHILD_EXIT")!=1:
        raise ValueError("foreign MM corruption/repair not exactly matched")
    path.write_text(script,encoding="ascii")
    (work/"expected-v1912.txt").write_text(
         "target_meta %06o\ntarget_call %06o\ntransition_clear %06o\n"
         "source_return %06o\nservice_return %06o\nchild_exit %06o\n"
         "table %06o\nuarea %06o\n" %
         (target_meta,expected["target_call"],
          expected["transition_clear"],expected["source_return"],
          expected["service_return"],core["proc_exit_current"],
          expected["process_table"],expected["uarea"]),encoding="ascii")
    print("v1912: original post-last-orphan target repair and native terminal HALT")


if __name__=="__main__":
    if len(sys.argv)!=6:
        raise SystemExit("usage: prepare-physical-v1912.py kit build probe work prefix")
    try:
        prepare(*(Path(x) for x in sys.argv[1:]))
    except (OSError,ValueError,KeyError,AssertionError) as exc:
        raise SystemExit("FAIL v1912 late terminal reconciliation setup: "+str(exc))
