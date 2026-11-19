#!/usr/bin/env python3
"""Audit the first original 48K v1384 PURE prefix claim and commit.

The restored user and parent must continue to EXIT/WAIT after the
breakpoint observations. Do not infer other owners' path choices.
"""

import argparse
from pathlib import Path
import re
import subprocess


def symbols(text):
    result = {}
    for line in text.splitlines():
        parts = line.split()
        if len(parts) >= 2 and re.fullmatch(r"[0-7]+", parts[1]):
            result[parts[0]] = int(parts[1], 8)
    return result


def audit(map_text, dxr_image, trace, user_source):
    mapped = symbols(map_text)
    assert mapped.get("mm_pure_claim_prefix_v1384") == 0o2561
    assert mapped.get("mm_pure_release_prefix_v1384") == 0o2563
    assert mapped.get("mm_pure_commit_prefix_v1384") == 0o2565
    assert mapped.get("proc_pure_ram_restore_v1391") == 0o2207
    assert "IMAGE  002561 400000000000" in dxr_image
    assert "IMAGE  002565 201000000002" in dxr_image
    assert "MEM                                  48 K" in trace
    assert "PURE                              LOADED" in trace
    for address, word in ((0o34610, "400000000000"),
                          (0o34614, "201000000002")):
        sample = "%o:\t%s" % (address, word)
        assert trace.count(sample) == 1, \
            "installed PURE opcode not source-authenticated: " + sample
    assert "V1630_RESTORE_BEGIN" in trace
    assert "V1630_FIRST_BRANCH" in trace
    assert "V1630_SECOND_BRANCH" in trace
    one = re.search(r"Breakpoint, PC: 034610 \(SETZ 0,0\)\n"
                    r"V1630_FIRST_BRANCH\n"
                    r"1:\s*([0-7]+)\n2:\s*([0-7]+)\n"
                    r"3:\s*([0-7]+)\n4:\s*([0-7]+)", trace)
    two = re.search(r"Breakpoint, PC: 034614 \(MOVEI 0,2\)\n"
                    r"V1630_SECOND_BRANCH\n"
                    r"1:\s*([0-7]+)\n2:\s*([0-7]+)\n"
                    r"3:\s*([0-7]+)\n4:\s*([0-7]+)", trace)
    assert one and two, "genuine ordered prefix claim and commit absent"
    assert tuple(int(x, 8) for x in one.groups()) == (
        0o117000, 2, 0o1000, 0o10000)
    assert tuple(int(x, 8) for x in two.groups()) == (
        0o116000, 2, 0o1000, 0o10000)
    assert trace.index(one.group(0)) < trace.index(two.group(0))
    assert "Breakpoint, PC: 034236" not in trace[:trace.index(two.group(0))], \
        "full restore occurred before in-place commit"
    assert "aaaaax[B" in trace and "L" in trace
    assert re.search(r"wwwwwZ\s*\nHALT instruction", trace), \
        "live guest did not finish five WAITs and HALT"
    assert re.search(r"(?m)^#define P14_CHILDREN\s+5U$", user_source)
    assert "if (denied != -1)" in user_source
    assert "dsys_wait((unsigned int)pid[i], &status, 0U)" in user_source
    assert "SYS_WAIT_STATUS_VALUE(status) != P14_STATUS" in user_source
    assert "(void)p14_char('Z');" in user_source
    print("PASS v1630: original owner-2 prefix claim 034610 -> commit 034614")
    print("PASS v1630: original full APR 010000, zero-copy writable suffix")
    print("PASS v1630: user PIPE/data, five WAIT/EXIT and terminal HALT")
    print("v1630: does NOT prove relocated FULL restore or peak/net RAM")


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("pure_map", type=Path)
    parser.add_argument("pure_dxr", type=Path)
    parser.add_argument("physical_trace", type=Path)
    parser.add_argument("guest_source", type=Path)
    parser.add_argument("--dxrcheck", default="dxrcheck")
    args = parser.parse_args()
    try:
        dxr = subprocess.check_output(
            [args.dxrcheck, "-d", str(args.pure_dxr)],
            text=True, encoding="ascii")
        audit(args.pure_map.read_text(encoding="ascii"), dxr,
              args.physical_trace.read_text(encoding="ascii"),
              args.guest_source.read_text(encoding="ascii"))
    except (AssertionError, UnicodeError, subprocess.CalledProcessError) as e:
        parser.exit(1, "FAIL v1630 original restore path: %s\n" % e)


if __name__ == "__main__":
    main()
