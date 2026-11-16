#!/usr/bin/env python3
"""Source-backed physical PDP-6 PURE PIPE/WAIT/EXIT lifecycle auditor.

This gate does not infer RAW reclaimed words from the logical MEMINFO
counters or claim a whole-system RAM saving from process markers.
"""

import argparse
from pathlib import Path
import re


def audit(source, trace, manifest, dxr):
    assert re.search(r"(?m)^#define P14_CHILDREN\s+6U$", source)
    assert re.search(r"(?m)^#define P14_BRK_TARGET\s+017000UL$", source)
    assert re.search(r"(?m)^#define P14_STATUS\s+057U$", source)
    assert "p14_fail('r');" in source and "p14_fail('s');" in source
    assert "(void)p14_char('L');" in source
    assert "(void)p14_char('Z');" in source
    assert "SYS_WAIT_STATUS_VALUE(status) != P14_STATUS" in source
    assert "SYS_WAIT_STATUS_KIND(status) != SYS_WAIT_EXITED" in source
    assert "got != pid[i]" in source
    assert "dsys_wait((unsigned int)pid[i], &status, 0U)" in source
    assert "p14_data[0] != 012345670123UL" in source
    assert "p14_data[P14_IMAGE_WORDS - 1U] != 076543210765UL" in source
    assert "dsys_read_words(0, &word, 1U)" in source
    assert "purity=PURE" in dxr
    assert "F /SYSTEM/INIT " in manifest

    assert "MEM                                  64 K" in trace
    assert "PURE                              LOADED" in trace
    line = ("aaaaaa[B073470/042522]<010000+017000>"
            "[A103470/042522]{073470-103470}LwwwwwwZ")
    assert trace.count(line) == 1, "physical complete parent/child trace drifted"
    tail = trace.split(line, 1)[1]
    assert re.match(r"\s*HALT instruction", tail), \
        "missing terminal physical PDP-6 HALT"
    assert "!" not in line
    return "six child PIPE/read/data/exit statuses and parent WAIT/Z complete"


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("guest_source", type=Path)
    parser.add_argument("physical_trace", type=Path)
    parser.add_argument("tsfs_manifest", type=Path)
    parser.add_argument("dxrcheck_log", type=Path)
    args = parser.parse_args()
    try:
        result = audit(args.guest_source.read_text(encoding="ascii"),
                       args.physical_trace.read_text(encoding="ascii"),
                       args.tsfs_manifest.read_text(encoding="ascii"),
                       args.dxrcheck_log.read_text(encoding="ascii"))
    except (AssertionError, UnicodeError) as exc:
        parser.exit(1, "FAIL v1627 physical lifecycle: %s\n" % exc)
    print("PASS v1627 physical lifecycle: " + result)
    print("v1627: parent BRK has no additional RAM-savings proof")


if __name__ == "__main__":
    main()
