#!/usr/bin/env python3
"""Exercise the original last orphan through twelve further capped retries."""

from pathlib import Path
import os
import runpy
import shutil
import sys


EXTRA_RETRIES = 12


def prepare(kit, build, probe, work, prefix):
    previous = runpy.run_path(str(kit / "tests/validation/"
                              "pure-k05-last-orphan-v1911/prepare-physical-v1911.py"))
    previous["prepare"](kit, build, probe, work, prefix)
    symbols = runpy.run_path(str(kit / "tests/validation/"
                              "pure-k05-secondary-physical-v1845/prepare-v1845.py"))
    core = symbols["symbols"](build / "kcore.map")
    original = (Path(os.environ["DAIMOS_REPO"]) /
                "system/kernel/proc/proc_pdp6.s").read_text(encoding="ascii")
    # Assert the original service cannot HALT without a completion
    # and that its timer-backoff bit is kept through failed retries.
    for fragment in ("proc_finish_service_done_v881:",
                     "trne    11,2", "andi    11,1",
                     "jumpe   1,proc_finish_service_return_v881",
                     "jumpn   3,proc_exit_halt",
                     "proc_has_live_user_scan:"):
        if fragment not in original:
            raise ValueError("original last-user terminal policy drift: " + fragment)
    path = work / "physical.ini"
    script = path.read_text(encoding="ascii")
    old_tail = "echo V1911_OPERATOR_STOP_NO_CHILD_HALT\nexit\n"
    if script.count(old_tail) != 1 or not script.endswith(old_tail):
        raise ValueError("accepted v1911 operator-stop stage drift")
    shutil.copyfile(path, work / "physical-v1911.ini")
    first = "echo V1911_STAGE_LAST_PI6\n"
    last = "echo V1911_END_LAST_PI6\n"
    if script.count(first) != 1 or script.count(last) != 1:
        raise ValueError("original v1911 post-PI6 MM10 snapshot drift")
    snapshot = script.split(first, 1)[1].split(last, 1)[0]
    if not snapshot.startswith("examine ") or any(
            not line.startswith("examine ") for line in snapshot.splitlines()):
        raise ValueError("v1911 owner snapshot no longer read-only")

    def stage(name):
        return ("echo V1913_STAGE_%s\n" % name + snapshot +
                "echo V1913_END_%s\n" % name)

    # No owner correction, free reply substitution, or guest code gate.
    # Every retry has an actual idle-loop completion, preventing SIMH
    # breakpoint rearming from stopping on one unexecuted instruction.
    appended = ""
    for i in range(1, EXTRA_RETRIES + 1):
        appended += (
            "nobreak all\nbreak %06o\ncont\n" % core["proc_finish_service_v881"] +
            "echo V1913_REAL_ORPHAN_RETRY_%02d\n" % i +
            stage("RETRY_%02d" % i) +
            "nobreak all\nbreak %06o\ncont\n" % core["proc_idle_loop"] +
            "echo V1913_REAL_ORPHAN_RETRY_DONE_%02d\n" % i +
            stage("RETRY_DONE_%02d" % i))
        if i in (6, EXTRA_RETRIES):
            appended += (
                "nobreak all\nbreak %06o\ncont\n" % core["proc_sched_pi_tick"] +
                "echo V1913_ORIGINAL_HELD_PI6_%02d\n" % i +
                "examine %06o\n" % core["pdp10_pi_level6"] +
                stage("PI6_%02d" % i))
    appended += "echo V1913_OPERATOR_STOP_UNREPAIRED_ORPHAN\nexit\n"
    if appended.count("break %06o\n" % core["proc_finish_service_v881"]) != EXTRA_RETRIES or \
       appended.count("break %06o\n" % core["proc_idle_loop"]) != EXTRA_RETRIES or \
       appended.count("break %06o\n" % core["proc_sched_pi_tick"]) != 2 or \
       "deposit " in appended or "V1906_FOREIGN_TARGET_REPAIR" in script:
        raise ValueError("v1913 cannot write owner, simulate retries or forge HALT")
    script = script[:-len(old_tail)] + appended
    path.write_text(script, encoding="ascii")
    (work / "expected-v1913.txt").write_text(
        "extra_retries %06o\nretry_pc %06o\nidle_pc %06o\n"
        "pi6_pc %06o\nclock %06o\nlast_retry %06o\n" %
        (EXTRA_RETRIES, core["proc_finish_service_v881"],
         core["proc_idle_loop"], core["proc_sched_pi_tick"],
         core["proc_timer_clock"], core["proc_timer_clock"] + 2),
        encoding="ascii")
    print("v1913: %d additional original orphan retries, 2 actual PI6; no repair" %
          EXTRA_RETRIES)


if __name__ == "__main__":
    if len(sys.argv) != 6:
        raise SystemExit("usage: prepare-physical-v1913.py kit build probe work prefix")
    try:
        prepare(*(Path(x) for x in sys.argv[1:]))
    except (OSError, ValueError, KeyError, AssertionError) as exc:
        raise SystemExit("FAIL v1913 permanent orphan setup: " + str(exc))
