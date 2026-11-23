#!/usr/bin/env python3
"""Execute corrupted original physical owner/clock/heartbeat transcripts."""

from pathlib import Path
import re
import subprocess
import sys


def mutate(text, begin, end, target, replacement):
    a = "V1895_%s\n" % begin
    b = "V1895_%s\n" % end
    if text.count(a) != 1 or text.count(b) != 1:
        raise ValueError("actual original K05 physical checkpoint not unique")
    left, rest = text.split(a, 1)
    middle, right = rest.split(b, 1)
    if middle.count(target) != 1:
        raise ValueError("original physical marker or word not unique")
    return left + a + middle.replace(target, replacement, 1) + b + right


def field(text, begin, end, address, old, new):
    return mutate(text, begin, end,
                  "%o:\t%012o" % (address, old),
                  "%o:\t%012o" % (address, new))


def physical_word(text, begin, end, address):
    start = "V1895_%s\n" % begin
    stop = "V1895_%s\n" % end
    middle = text.split(start, 1)[1].split(stop, 1)[0]
    matches = re.findall(r"(?m)^%o:\s*([0-7]{12})\s*$" % address, middle)
    if len(matches) != 1:
        raise ValueError("not exactly one original physical MM word")
    return int(matches[0], 8)


def run(kit, build, work, verifier=None):
    trace_file = work / "physical.clean"
    original = trace_file.read_text(encoding="ascii")
    expected = dict((k, int(v, 8)) for k, v in re.findall(
        r"(?m)^([a-z0-9_]+)\s+([0-7]+)\s*$",
        (work / "expected-v1895.txt").read_text(encoding="ascii")))
    core = dict((k, int(v, 8)) for k, v in re.findall(
        r"(?m)^(\S+)\s+([0-7]{6})\s*$",
        (build / "kcore.map").read_text(encoding="ascii")))
    meta = expected["source_meta_address"]
    target = meta + 2
    targetpin0 = physical_word(original, "STAGE_HEARTBEAT_1",
                               "END_HEARTBEAT_1", target)
    current_slot = core["proc_current_slot"]
    clock = core["proc_timer_clock"]
    second_clock = physical_word(original, "STAGE_HEARTBEAT_2",
                                 "END_HEARTBEAT_2", clock)
    first_clock = physical_word(original, "STAGE_HEARTBEAT_1",
                                "END_HEARTBEAT_1", clock)
    table = expected["process_table"]
    slot3 = physical_word(original, "STAGE_HEARTBEAT_1",
                          "END_HEARTBEAT_1", table + 9)
    vm3 = physical_word(original, "STAGE_HEARTBEAT_2",
                        "END_HEARTBEAT_2", table + 10)
    if targetpin0 != 0o000001000003 or not (slot3 & (1 << 16)) or \
            second_clock <= first_clock:
        raise ValueError("original physically verified checkpoint geometry drift")
    mutants = [
        ("no-actual-native-free-refusal",
         original.replace("V1894_ACTUAL_MM_FREE_REFUSAL\n1:\t777777777773",
                          "V1894_ACTUAL_MM_FREE_REFUSAL\n1:\t000000000000", 1),
         "original real fixed KCORE mm_free did not return -5"),
        ("persistent-pin-disappeared-before-original-service",
         field(original, "PERSISTENT_EXTERNAL_SOURCE_PIN", "END_PERSISTENT_PIN",
               meta, expected["source_meta_pin1"], expected["source_meta_pin0"]),
         "persistent external PACKED pin unexpectedly released"),
        ("source-pin-lost-on-first-user-heartbeat",
         field(original, "STAGE_HEARTBEAT_1", "END_HEARTBEAT_1",
               meta, expected["source_meta_pin1"], expected["source_meta_pin0"]),
         "persistent source pin lost exact original owners"),
        ("extra-target-pin-on-second-heartbeat",
         field(original, "STAGE_HEARTBEAT_2", "END_HEARTBEAT_2",
               target, targetpin0, targetpin0 + (1 << 21)),
         "persistent source pin lost exact original owners"),
        ("quarantined-slot3-transition-cleared",
         field(original, "STAGE_HEARTBEAT_1", "END_HEARTBEAT_1",
               table + 9, slot3, slot3 & ~(1 << 16)),
         "quarantined slot3 lost TRANSITION or published APR"),
        ("quarantined-slot3-runnable-apr-forged",
         field(original, "STAGE_HEARTBEAT_2", "END_HEARTBEAT_2",
               table + 10, vm3, vm3 | 0o120000),
         "quarantined slot3 lost TRANSITION or published APR"),
        ("heartbeat-wrong-current-user",
         field(original, "STAGE_HEARTBEAT_1", "END_HEARTBEAT_1",
               current_slot, 1, 3),
         "user HB not executing from actual resident parent"),
        ("stale-real-pclk-on-second-heartbeat",
         field(original, "STAGE_HEARTBEAT_2", "END_HEARTBEAT_2",
               clock, second_clock, first_clock),
         "original PCLK clock failed to advance across user HBs"),
        ("original-full-service-false-success",
         mutate(original, "ORIGINAL_QUARANTINED_FULL_RETURN",
                "STAGE_QUARANTINED", "1:\t777777777773",
                "1:\t000000000000"),
         "genuine source-free refusal was not retained as -5"),
        ("second-user-heartbeat-not-emitted",
         mutate(original, "END_HEARTBEAT_1",
                "ACTUAL_RESIDENT_HEARTBEAT_2", "HB", "XX"),
         "second independent parent HB not physically emitted"),
    ]
    original_bytes = trace_file.read_bytes()
    for label, fake, check in mutants:
        if fake == original:
            raise ValueError("unsafe physical forged transcript is unchanged: " + label)
        trace_file.write_text(fake, encoding="ascii")
        try:
            proc = subprocess.run([
                sys.executable,
                str(verifier or kit / "tests/validation/pure-k05-persistent-source-pin-v1895/"
                    "verify-v1895.py"), str(kit), str(build), str(work)],
                stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
        finally:
            trace_file.write_bytes(original_bytes)
        if proc.returncode == 0 or check not in proc.stderr:
            raise ValueError("original unsafe %s not rejected at intended check: %s"
                             % (label, proc.stderr.strip()))
        print("PASS v1895: unsafe physical %s transcript rejected" % label)


if __name__ == "__main__":
    if len(sys.argv) not in (4, 5):
        raise SystemExit("usage: negative-v1895.py kit original-build physical-work [versioned-verifier]")
    try:
        run(*(Path(a) for a in sys.argv[1:]))
    except (ValueError, KeyError, OSError, AssertionError) as exc:
        raise SystemExit("FAIL v1895 persistent source-pin negative oracle: " + str(exc))
