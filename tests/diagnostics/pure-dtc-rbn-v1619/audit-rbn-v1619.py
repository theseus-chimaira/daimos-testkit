#!/usr/bin/env python3
"""Audit real PDP-6 Type-551 RBN match, and optional PI3/PI5 transfer.

The original v1618 tape image and test-only symbol map identify the
physical branch instructions. No kernel or controller is emulated.
"""
import re
import subprocess
import sys
from pathlib import Path


def symbols(path):
    result = {}
    for line in Path(path).read_text().splitlines():
        words = line.split()
        if len(words) >= 2 and not words[1].strip("01234567"):
            result[words[0]] = int(words[1], 8)
    return result


def original_image(path, tool):
    text = subprocess.check_output([tool, "-d", path], text=True)
    return {int(a, 8): int(w, 8) for a, w in re.findall(
        r"(?m)^IMAGE\s+([0-7]{6})\s+([0-7]{12})$", text)}


def core_words(block):
    words = {}
    for a, w in re.findall(
            r"(?m)(?<![0-7])([0-7]{4,7}):\s*([0-7]{1,12})(?=\s|$)",
            block):
        address = int(a, 8)
        value = int(w, 8)
        if address in words and words[address] != value:
            raise ValueError("inconsistent repeated physical word %06o" %
                             address)
        words[address] = value
    return words


def stage_blocks(trace):
    chunks = re.split(
        r"(?m)^Breakpoint, PC: ([0-7]{6})[^\n]*\n", trace)
    return [(int(chunks[i], 8), core_words(chunks[i + 1]))
            for i in range(1, len(chunks) - 1, 2)]


def read_at(stages, pc, address):
    hits = [s for p, s in stages if p == pc]
    if len(hits) != 1 or address not in hits[0]:
        raise ValueError("missing unique physical stage %06o word %06o" %
                         (pc, address))
    return hits[0][address]


def audit(kmap, tapemap, tapedxr, source, trace, dxrcheck, mode):
    if mode not in ("match", "transfer"):
        raise ValueError("mode must be match or transfer")
    kernel = symbols(kmap)
    tape = symbols(tapemap)
    for name, expected in (("dtc_search_pi_found", 0o415),
                           ("dtc_search_pi_read", 0o455),
                           ("tape_dct_done_keep_dtc", 0o124),
                           ("dtc_search_fail", 0o463)):
        if tape.get(name) != expected:
            raise ValueError("test-only tape symbol map changed: " + name)
    image = original_image(tapedxr, dxrcheck)
    if (image.get(0o343) != 0o561200761740 or
            image.get(0o405) != 0o561100761740):
        raise ValueError("original physical tape DXR is not 120-second v1618")
    src = Path(source).read_text()
    for snippet in ("dtc_search_pi_found:", "dtc_search_pi_read:",
                    "tape_dct_done_keep_dtc:", "dtc_search_fail:"):
        if snippet not in src:
            raise ValueError("original Type-551 source label missing")
    body = Path(trace).read_text()
    if ("PURE" not in body or "LOADED" not in body or
            "<010000+020000>" not in body):
        raise ValueError("missing genuine 48K PURE BRK pressure trigger")
    stages = stage_blocks(body)
    base = 0o30431
    found = base + 0o415
    read = base + 0o455
    done = base + 0o124
    fail = base + 0o463
    if any(p == fail for p, _ in stages):
        raise ValueError("Type-551 entered search failure before acceptance")
    if read_at(stages, found, kernel["storage_state"]) != 0o200:
        raise ValueError("matched RBN did not originate in DTC search")
    # The match-only probe examines the complete tape BSS at RBN match.
    # The multi-stage probe examines it at DCT completion (the same
    # request), while its earlier stops capture state and last mark.
    owner_stage = found if mode == "match" else done
    if read_at(stages, owner_stage, 0o31240) != 0:
        raise ValueError("RBN unit was not DTC0")
    if read_at(stages, owner_stage, 0o31241) != 0:
        raise ValueError("RBN was not a read")
    if read_at(stages, owner_stage, 0o31242) != 0o10000:
        raise ValueError("RBN was not searching in reverse")
    if read_at(stages, owner_stage, 0o31243) != 4:
        raise ValueError("unexpected physical RBN target")
    if read_at(stages, found, 0o31245) != 4:
        raise ValueError("last PI3 block mark did not equal requested RBN")
    print("PASS v1619 physical full PURE guest: DTC0 reverse RBN=000004")
    if mode == "transfer":
        if read_at(stages, read, kernel["storage_state"]) != 0o200:
            raise ValueError("PI3 read command was not armed from search")
        if read_at(stages, read, 0o31245) != 4:
            raise ValueError("PI3 read path lost the matched RBN")
        # In the original DTC read driver, DCT data completion (not
        # tape_pi_done on PI5) negates state -1 and wakes the waiter.
        if read_at(stages, done, kernel["storage_state"]) != (
                (1 << 36) - 1):
            raise ValueError("DCT completion was not DTC read state -1")
        if read_at(stages, done, kernel["storage_count"]) != 0o200:
            raise ValueError("reverse DCT read did not complete 0200 words")
        if read_at(stages, done, 0o31246) != 0:
            raise ValueError("DCT completion event already published")
        print("PASS v1619 full guest PI3 read arm and DCT data completion")
        print("OPEN v1619: VFS prefix commit/rollback and slot-0 RUN/WAIT")
    else:
        print("OPEN v1619: physical DCT read completion and VFS restoration")


def main():
    if len(sys.argv) != 8:
        raise ValueError(
            "usage: audit-rbn-v1619.py KCORE.map TAPE-SYMS.map TAPE.dxr "
            "TAPE.s TRACE.clean DXRCHECK match|transfer")
    audit(*sys.argv[1:])


if __name__ == "__main__":
    try:
        main()
    except (ValueError, OSError, subprocess.CalledProcessError) as error:
        raise SystemExit("FAIL v1619 physical RBN audit: " + str(error))
