#!/usr/bin/env python3
"""Strict post-HALT evidence for the v1541 physical Type-236 test.

The actual PDP-6 guest and v1511 instrumented Type-236 completion
produce this evidence. The verifier cannot create or trigger a HALT.
Use --self-test to execute corrupt-evidence rejection mutations.
"""

from pathlib import Path
import re
import sys


def symbol_value(mapping, label):
    match = re.search(r"(?m)^" + re.escape(label) +
                      r"\s+([0-7]{6})\s*$", mapping)
    if match is None:
        raise AssertionError("missing unique linked symbol: " + label)
    return int(match.group(1), 8)


def witness_value(posthalt, address, label):
    pattern = r"(?m)^(?:sim>\s*)?0*%o:\s*([0-7]{1,12})\s*$" % address
    matches = re.findall(pattern, posthalt)
    if len(matches) != 1:
        raise AssertionError("missing or ambiguous post-HALT " + label)
    return int(matches[0], 8)


def verify(mapping, transcript, raw, gateway, driver, samples):
    fatal_entry = symbol_value(mapping, "kcore_critical_device_lost_v1515")
    addresses = {
        "pi2_errors": symbol_value(mapping, "daimos_v1511_device_errors"),
        "enabled": symbol_value(mapping, "backstore_enabled"),
        "used": symbol_value(mapping, "backstore_blocks_used"),
    }
    expected_pc = fatal_entry + 7
    halted = re.findall(r"HALT instruction, PC: ([0-7]{6})", transcript)
    if len(halted) != 1 or int(halted[0], 8) != expected_pc:
        raise AssertionError("not the unique linked BACKSTORE HALT")
    if "FAIL_" in transcript or "ERROR_RETURNED" in transcript:
        raise AssertionError("guest reported an ordinary error/return")
    raw_halt = re.findall(r"HALT instruction, PC: ([0-7]{6})", raw)
    if len(raw_halt) != 1 or int(raw_halt[0], 8) != expected_pc:
        raise AssertionError("raw simulator HALT disagrees")
    posthalt = raw.split("HALT instruction, PC:", 1)[1]
    values = {
        key: witness_value(posthalt, address, key)
        for key, address in addresses.items()
    }
    if values["pi2_errors"] != 1:
        raise AssertionError("no exact selected physical PI2 error")
    if values["enabled"] == 0 and values["used"] == 0:
        raise AssertionError("BACKSTORE was not critical at failure")
    if values["used"] < 1:
        raise AssertionError("no actual owned swap backing at HALT")

    gate = gateway[gateway.index("blockset_direct_tail_done:\n"):]
    for instruction in (
            "skipn   backstore_enabled",
            "skipn   backstore_blocks_used",
            "movei   1,2\n        jrst    kcore_critical_device_lost_v1515"):
        if instruction not in gate:
            raise AssertionError("production BACKSTORE gate changed")

    for code in ("daimos_v1511_target_descriptor",
                 "aos     daimos_v1511_device_errors",
                 "jrst    drm236_pi_error",
                 "drm236_pi_handler:"):
        if code not in driver:
            raise AssertionError("instrumented real PI2 path absent: " + code)

    baseline = re.findall(
        r"v1541 sample=\d+ .+ pi2_device_errors=(\d+)", samples)
    if len(baseline) < 2 or any(int(n) != 0 for n in baseline):
        raise AssertionError("no clean pre-error physical baseline")
    return expected_pc, values, len(baseline)


def reject_mutants(data):
    mapping, transcript, raw, gateway, driver, samples = data
    pc = symbol_value(mapping, "kcore_critical_device_lost_v1515") + 7
    correct = "%06o" % pc
    post = raw.split("HALT instruction, PC:", 1)[1]
    err = symbol_value(mapping, "daimos_v1511_device_errors")
    used = symbol_value(mapping, "backstore_blocks_used")
    enabled = symbol_value(mapping, "backstore_enabled")

    def change_value(original, address, replace):
        prefix, posthalt = original.split("HALT instruction, PC:", 1)
        pattern = r"(?m)^sim> 0*%o:\s*[0-7]{1,12}\s*$" % address
        replacement = "sim> %o:\t%012o" % (address, replace)
        found = list(re.finditer(pattern, posthalt))
        if len(found) != 1:
            raise AssertionError("mutation fixture did not find exact word")
        m = found[0]
        return (prefix + "HALT instruction, PC:" +
                posthalt[:m.start()] + replacement + posthalt[m.end():])

    start = gateway.index("blockset_direct_tail_done:\n")
    broken_gate = (gateway[:start] +
                   gateway[start:].replace(
                       "skipn   backstore_blocks_used",
                       "skipn   test_fake_owner", 1))
    tests = [
        ("wrong-halt-reason",
         (mapping, transcript.replace(correct, "%06o" % (pc - 4), 1),
          raw, gateway, driver, samples)),
        ("duplicated-halt",
         (mapping, transcript + "\nHALT instruction, PC: " + correct + "\n",
          raw, gateway, driver, samples)),
        ("missing-raw-halt",
         (mapping, transcript, raw.replace("HALT instruction, PC:", "STOP PC:", 1),
          gateway, driver, samples)),
        ("no-controller-error",
         (mapping, transcript, change_value(raw, err, 0),
          gateway, driver, samples)),
        ("no-owned-blocks",
         (mapping, transcript, change_value(raw, used, 0),
          gateway, driver, samples)),
        ("no-active-flag-or-owner",
         (mapping, transcript,
          change_value(change_value(raw, enabled, 0), used, 0),
          gateway, driver, samples)),
        ("missing-source-gate",
         (mapping, transcript, raw,
          broken_gate, driver, samples)),
        ("missing-PI2-driver",
         (mapping, transcript, raw, gateway,
          driver.replace("aos     daimos_v1511_device_errors",
                         "setzm   daimos_v1511_device_errors", 1), samples)),
        ("false-pre-error-baseline",
         (mapping, transcript, raw, gateway, driver,
          samples.replace("pi2_device_errors=0", "pi2_device_errors=1", 1))),
    ]
    for name, mutant in tests:
        try:
            verify(*mutant)
        except AssertionError:
            print("PASS v1542: rejected " + name)
        else:
            raise AssertionError("accepted corrupted witness " + name)
    return len(tests)


def main():
    args = list(sys.argv[1:])
    self_test = "--self-test" in args
    if self_test:
        args.remove("--self-test")
    if len(args) != 6:
        raise SystemExit("usage: v1542-verifier [--self-test] MAP "
                         "CONSOLE RAW GATE DRIVER SAMPLES")
    data = tuple(Path(path).read_text(errors="replace") for path in args)
    pc, values, baseline = verify(*data)
    print("PASS v1542: native PDP-6 Type-236 PI2 BACKSTORE HALT %06o" % pc)
    print("PASS v1542: error=%d enabled=%d owned=%06o pre-error-samples=%d" %
          (values["pi2_errors"], values["enabled"], values["used"],
           baseline))
    if self_test:
        count = reject_mutants(data)
        print("PASS v1542: %d corrupted physical witnesses rejected" % count)
    return 0


if __name__ == "__main__":
    sys.exit(main())
