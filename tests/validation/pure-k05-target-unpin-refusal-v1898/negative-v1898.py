#!/usr/bin/env python3
"""Execute unsafe transcript mutations against two original native unpins."""

from pathlib import Path
import re
import subprocess
import sys


def replace(text, first, last, old, new):
    start = "V1898_%s\n" % first
    stop = "V1898_%s\n" % last
    if text.count(start) != 1 or text.count(stop) != 1:
        raise ValueError("original source-linked physical boundary not unique")
    left, rest = text.split(start, 1)
    body, right = rest.split(stop, 1)
    if body.count(old) != 1:
        raise ValueError("unsafe original physical value not uniquely observed")
    return left + start + body.replace(old, new, 1) + stop + right


def field(text, first, last, addr, before, after):
    return replace(text, first, last,
                   "%o:\t%012o" % (addr, before),
                   "%o:\t%012o" % (addr, after))


def phys(text, first, last, addr):
    start = "V1898_%s\n" % first
    stop = "V1898_%s\n" % last
    body = text.split(start, 1)[1].split(stop, 1)[0]
    matches = re.findall(r"(?m)^%o:\s*([0-7]{12})\s*$" % addr, body)
    if len(matches) != 1:
        raise ValueError("original hardware address not found uniquely")
    return int(matches[0], 8)


def run(kit, build, work):
    clean = work / "physical.clean"
    exact_bytes = clean.read_bytes()
    original = exact_bytes.decode("ascii")
    exp = dict((k, int(v, 8)) for k, v in re.findall(
        r"(?m)^([a-z0-9_]+)\s+([0-7]+)\s*$",
        (work / "expected-v1898.txt").read_text(encoding="ascii")))
    mapvals = dict((k, int(v, 8)) for k, v in re.findall(
        r"(?m)^(\S+)\s+([0-7]{6})\s*$",
        (build / "kcore.map").read_text(encoding="ascii")))
    meta = exp["target_meta_address"]
    slot3 = phys(original, "STAGE_HEARTBEAT_1", "END_HEARTBEAT_1",
                 exp["process_table"] + 9)
    vm3 = phys(original, "STAGE_HEARTBEAT_2", "END_HEARTBEAT_2",
               exp["process_table"] + 10)
    first_clock = phys(original, "STAGE_HEARTBEAT_1", "END_HEARTBEAT_1",
                       mapvals["proc_timer_clock"])
    second_clock = phys(original, "STAGE_HEARTBEAT_2", "END_HEARTBEAT_2",
                        mapvals["proc_timer_clock"])
    if not (slot3 & (1 << 16)) or second_clock <= first_clock:
        raise ValueError("original physical checkpoint geometry drifted")
    cases = [
        ("target-did-not-begin-pin1",
         field(original, "ORIGINAL_TARGET_UNPIN_CALL", "STAGE_BEFORE_TARGET_UNPIN",
               meta, exp["target_meta_pin1"], exp["target_meta_pin0"]),
         "original target did not have one pin at native unpin call"),
        ("test-zero-pin-not-injected",
         field(original, "TEST_ONLY_ZERO_TARGET_PIN", "END_TEST_ONLY_ZERO_TARGET_PIN",
               meta, exp["target_meta_pin0"], exp["target_meta_pin1"]),
         "external test-only zero target pin not actually injected"),
        ("first-native-unpin-falsely-succeeded",
         field(original, "ORIGINAL_FIRST_UNPIN_REFUSAL", "STAGE_FIRST_UNPIN_REFUSED",
               1, 0o777777777774, 0),
         "original native FIRST_UNPIN_REFUSED did not return genuine MM_ERR_INVAL -4"),
        ("first-refusal-physically-mutated-target-pin",
         field(original, "STAGE_FIRST_UNPIN_REFUSED", "END_FIRST_UNPIN_REFUSED",
               meta, exp["target_meta_pin0"], exp["target_meta_pin1"]),
         "original double native unpin refusal changed owners"),
        ("cleanup-did-not-retry-zero-pin",
         field(original, "ORIGINAL_CLEANUP_TARGET_UNPIN_CALL", "STAGE_CLEANUP_UNPIN_CALL",
               meta, exp["target_meta_pin0"], exp["target_meta_pin1"]),
         "original cleanup did not retry already-zero target pin"),
        ("second-native-unpin-falsely-succeeded",
         field(original, "ORIGINAL_SECOND_UNPIN_REFUSAL", "STAGE_SECOND_UNPIN_REFUSED",
               1, 0o777777777774, 0),
         "original native SECOND_UNPIN_REFUSED did not return genuine MM_ERR_INVAL -4"),
        ("second-failure-destroyed-source-pin",
         field(original, "STAGE_SECOND_UNPIN_REFUSED", "END_SECOND_UNPIN_REFUSED",
               meta - 2, 0o000014000003, 0o000004000003),
         "original double native unpin refusal changed owners"),
        ("original-FULL-falsely-published-success",
         field(original, "ORIGINAL_FAILED_FULL_RETURN", "STAGE_QUARANTINED",
               1, 0o777777777773, 0),
         "original FULL did not report BUSY after two real -4"),
        ("quarantined-child-transition-cleared",
         field(original, "STAGE_HEARTBEAT_1", "END_HEARTBEAT_1",
               exp["process_table"] + 9, slot3, slot3 & ~(1 << 16)),
         "unsafe original slot3 TRANSITION or VM0 after unpin refusal"),
        ("quarantined-child-VM-falsely-published",
         field(original, "STAGE_HEARTBEAT_2", "END_HEARTBEAT_2",
               exp["process_table"] + 10, vm3, vm3 | 0o120000),
         "unsafe original slot3 TRANSITION or VM0 after unpin refusal"),
        ("parent-heartbeat-executed-from-wrong-slot",
         field(original, "STAGE_HEARTBEAT_1", "END_HEARTBEAT_1",
               mapvals["proc_current_slot"], 1, 3),
         "original user HB was not resident parent slot1"),
        ("PCLK-stalled-across-real-parent-heartbeats",
         field(original, "STAGE_HEARTBEAT_2", "END_HEARTBEAT_2",
               mapvals["proc_timer_clock"], second_clock, first_clock),
         "original PCLK did not advance between two genuine HBs"),
        ("second-user-heartbeat-was-not-emitted",
         replace(original, "END_HEARTBEAT_1", "PARENT_USER_HEARTBEAT_2",
                 "HB", "XX"),
         "original parent did not emit two real user heartbeats"),
    ]
    for name, changed, diagnostic in cases:
        if changed == original:
            raise ValueError("unsafe original physical negative was unchanged")
        clean.write_text(changed, encoding="ascii")
        try:
            p = subprocess.run([
                sys.executable,
                str(kit / "tests/validation/pure-k05-target-unpin-refusal-v1898/"
                    "verify-v1898.py"), str(kit), str(build), str(work)],
                stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
        finally:
            clean.write_bytes(exact_bytes)
        if p.returncode == 0 or diagnostic not in p.stderr:
            raise ValueError("unsafe %s physical negative not rejected as intended: %s"
                             % (name, p.stderr.strip()))
        print("PASS v1898: unsafe physical %s transcript rejected" % name)


if __name__ == "__main__":
    if len(sys.argv) != 4:
        raise SystemExit("usage: negative-v1898.py kit original-build physical-work")
    try:
        run(*(Path(a) for a in sys.argv[1:]))
    except (ValueError, KeyError, OSError, AssertionError) as exc:
        raise SystemExit("FAIL v1898 original physical double-unpin negatives: " + str(exc))
