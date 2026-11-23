#!/usr/bin/env python3
"""Execute unsafe original PDP6 source-unpin physical transcript controls."""

from pathlib import Path
import re
import subprocess
import sys


def change(trace, first, last, original, substitute):
    start = "V1899_%s\n" % first
    stop = "V1899_%s\n" % last
    if trace.count(start) != 1 or trace.count(stop) != 1:
        raise ValueError("physical source-unpin stage not unique")
    left, remaining = trace.split(start, 1)
    middle, right = remaining.split(stop, 1)
    if middle.count(original) != 1:
        raise ValueError("source-unpin unsafe value is not uniquely present")
    return left + start + middle.replace(original, substitute, 1) + stop + right


def altered_word(trace, first, last, address, original, substitute):
    return change(trace, first, last,
                  "%o:\t%012o" % (address, original),
                  "%o:\t%012o" % (address, substitute))


def captured_word(trace, first, last, address):
    start = "V1899_%s\n" % first
    stop = "V1899_%s\n" % last
    inside = trace.split(start, 1)[1].split(stop, 1)[0]
    found = re.findall(r"(?m)^%o:\s*([0-7]{12})\s*$" % address, inside)
    if len(found) != 1:
        raise ValueError("original process/MM word not unique")
    return int(found[0], 8)


def run(kit, build, work):
    source = work / "physical.clean"
    saved = source.read_bytes()
    original = saved.decode("ascii")
    expected = dict((k, int(v, 8)) for k, v in re.findall(
        r"(?m)^([a-z0-9_]+)\s+([0-7]+)\s*$",
        (work / "expected-v1899.txt").read_text(encoding="ascii")))
    core = dict((k, int(v, 8)) for k, v in re.findall(
        r"(?m)^(\S+)\s+([0-7]{6})\s*$",
        (build / "kcore.map").read_text(encoding="ascii")))
    addr = expected["source_meta_address"]
    slot3 = captured_word(original, "STAGE_FAILED_FULL", "END_FAILED_FULL",
                          expected["process_table"] + 9)
    vm3 = captured_word(original, "STAGE_FAILED_FULL", "END_FAILED_FULL",
                        expected["process_table"] + 10)
    if not slot3 & (1 << 16) or vm3 & 0o777777:
        raise ValueError("original physical source-unpin failure did not quarantine")
    cases = [
        ("original-source-not-pinned-at-native-call",
         altered_word(original, "ORIGINAL_SOURCE_UNPIN_CALL", "STAGE_SOURCE_UNPIN_CALL",
                      addr, expected["source_pin1"], expected["source_pin0"]),
         "original source did not have one pin at source unpin call"),
        ("source-zero-pin-fault-not-injected",
         altered_word(original, "TEST_ONLY_ZERO_SOURCE_PIN", "END_TEST_ONLY_ZERO_SOURCE_PIN",
                      addr, expected["source_pin0"], expected["source_pin1"]),
         "external zero-source-pin physical injection missing"),
        ("native-unpin-incorrectly-reported-success",
         altered_word(original, "ORIGINAL_NATIVE_SOURCE_UNPIN_REFUSAL",
                      "STAGE_SOURCE_REFUSED", 1, 0o777777777774, 0),
         "original native source mm_unpin did not genuinely return -4"),
        ("native-failure-falsely-retained-source-pin1",
         altered_word(original, "STAGE_SOURCE_REFUSED", "END_SOURCE_REFUSED",
                      addr, expected["source_pin0"], expected["source_pin1"]),
         "original source-unpin refusal changed physical MM owners"),
        ("target-rollback-entered-with-source-pin1",
         altered_word(original, "STAGE_TARGET_FREE_CALL", "END_TARGET_FREE_CALL",
                      addr, expected["source_pin0"], expected["source_pin1"]),
         "original failed-source-unpin target rollback not entered safely"),
        ("native-target-free-actually-refused",
         altered_word(original, "ORIGINAL_TARGET_FREE_COMMITTED",
                      "STAGE_TARGET_FREED", 1, 0, 0o777777777773),
         "original target rollback mm_free did not return MM_OK"),
        ("successful-target-free-lost-RAW-source-pin",
         altered_word(original, "STAGE_TARGET_FREED", "END_TARGET_FREED",
                      addr, expected["source_pin0"], expected["source_pin1"]),
         "original rollback lost RAW source or kept target after success"),
        ("FULL-falsely-reports-success",
         altered_word(original, "ORIGINAL_FULL_FAILURE_RETURN",
                      "STAGE_FAILED_FULL", 1, 0o777777777774, 0),
         "original FULL did not preserve real source-unpin -4 return"),
        ("process-table-pointer-corrupt",
         altered_word(original, "STAGE_FAILED_FULL", "END_FAILED_FULL",
                      core["proc_table"], expected["process_table"],
                      expected["process_table"] + 3),
         "original process table pointer not stable"),
        ("slot3-TRANSITION-falsely-cleared",
         altered_word(original, "STAGE_FAILED_FULL", "END_FAILED_FULL",
                      expected["process_table"] + 9,
                      slot3, slot3 & ~(1 << 16)),
         "original source-unpin error falsely published resident APR"),
        ("slot3-APR-falsely-published",
         altered_word(original, "STAGE_FAILED_FULL", "END_FAILED_FULL",
                      expected["process_table"] + 10, vm3, vm3 | 0o120000),
         "original source-unpin error falsely published resident APR"),
        ("failed-FULL-result-lost-RAW-owner",
         altered_word(original, "STAGE_FAILED_FULL", "END_FAILED_FULL",
                      addr, expected["source_pin0"], expected["source_pin1"]),
         "original FULL return lost sole RAW owner after target free"),
        ("original-five-child-HALT-missing",
         original.replace("HALT instruction, PC: 000000",
                          "HALT instruction, PC: 000001", 1),
         "original five child WAIT and real machine HALT did not recover"),
    ]
    for name, fake, diagnosis in cases:
        if fake == original:
            raise ValueError("original negative physical trace not modified")
        source.write_text(fake, encoding="ascii")
        try:
            result = subprocess.run([
                sys.executable,
                str(kit / "tests/validation/pure-k05-source-unpin-refusal-v1899/"
                    "verify-v1899.py"), str(kit), str(build), str(work)],
                stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
        finally:
            source.write_bytes(saved)
        if result.returncode == 0 or diagnosis not in result.stderr:
            raise ValueError("unsafe physical %s not rejected as intended: %s"
                             % (name, result.stderr.strip()))
        print("PASS v1899: unsafe original physical %s rejected" % name)


if __name__ == "__main__":
    if len(sys.argv) != 4:
        raise SystemExit("usage: negative-v1899.py kit original-build physical-work")
    try:
        run(*(Path(x) for x in sys.argv[1:]))
    except (ValueError, KeyError, OSError, AssertionError) as exc:
        raise SystemExit("FAIL v1899 original source-unpin negative audit: " + str(exc))
