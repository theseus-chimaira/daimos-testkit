#!/usr/bin/env python3
"""Original 48K guest: never repair the foreign FULL target; sample 10 HBs."""

from pathlib import Path
import runpy
import sys


def prepare(kit, build, probe, work, prefix):
    base = runpy.run_path(str(kit / "tests/validation/"
                        "pure-k05-foreign-term-v1907/prepare-physical-v1907.py"))
    base["prepare"](kit, build, probe, work, prefix)
    path = work / "physical.ini"
    script = path.read_text(encoding="ascii")
    anchor = "echo V1906_FOREIGN_TARGET_REPAIR\n"
    start = "echo V1906_STAGE_FOREIGN_HELD_HB_3\n"
    end = "echo V1906_END_FOREIGN_HELD_HB_3\n"
    if script.count(anchor) != 1 or script.count(start) != 1 or \
            script.count(end) != 1 or \
            script.index(end) >= script.index(anchor):
        raise ValueError("original source-linked foreign-owner stages drifted")
    snapshot = script.split(start,1)[1].split(end,1)[0]
    if not snapshot.startswith("examine ") or \
            any(line and not line.startswith("examine ")
                for line in snapshot.splitlines()):
        raise ValueError("foreign owner snapshot must be read-only")
    held = script.split(anchor,1)[0]
    # Keep the original first three HBs and native refused TERM. No
    # owner repair, no free-call breakpoint, no forced FINALIZE/EXIT,
    # and no parent WAIT gate deposit. The simulator operator exits
    # only AFTER heartbeat 10; the original guest remains quarantined.
    for i in range(4,11):
        held += ('nobreak all\nexpect "HB"\ncont\n'
                 'echo V1908_LONG_HELD_HB_%d\n'%i +
                 'echo V1908_STAGE_LONG_HELD_HB_%d\n'%i +
                 snapshot +
                 'echo V1908_END_LONG_HELD_HB_%d\n'%i)
    held += ('echo V1908_OPERATOR_STOP_NO_GUEST_HALT\n'
             'exit\n')
    if "V1906_FOREIGN_TARGET_REPAIR" in held or \
            "V1906_ORIGINAL_NATIVE_TARGET_FREE_CALL" in held or \
            "V1906_TEST_ONLY_PARENT_USER_GATE" in held or \
            'deposit 024725 000001000003' in held or \
            held.count('expect "TR"\ncont\n') != 1 or \
            held.count('expect "HB"\ncont\n') != 11:
        raise ValueError("long hold must not release, repair or fake cleanup")
    path.write_text(held,encoding="ascii")
    (work/"expected-v1908.txt").write_text(
        "heartbeat_count 000012\nmax_backoff 001000\n"
        "source_base 111200\ntarget_base 120000\n",
        encoding="ascii")
    print("v1908: retain genuine owner2 target through 10 parent HBs")
    print("v1908: expect bounded slot0 retry plateau at 001000 octal")


if __name__ == "__main__":
    if len(sys.argv)!=6:
        raise SystemExit("usage: prepare-physical-v1908.py kit build probe work prefix")
    try:
        prepare(*(Path(x) for x in sys.argv[1:]))
    except (OSError, ValueError, KeyError, AssertionError) as exc:
        raise SystemExit("FAIL v1908 original physical preparation: " + str(exc))
