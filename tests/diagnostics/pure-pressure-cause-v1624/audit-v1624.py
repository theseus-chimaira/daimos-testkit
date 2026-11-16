#!/usr/bin/env python3
"""Audit actual five/six-child PDP-6 pressure outcomes, not RAM savings.

The legacy v1621 six-child '!c' output combined RUN refusal and
failure to reach SLEEP.  This auditor accepts only source-authenticated
typed outcomes and retains a strict distinction between a physical
negative result and a completed P1-E lifecycle.
"""

import argparse
from pathlib import Path
import re


def audit(source, trace):
    count_match = re.search(r"(?m)^#define P14_CHILDREN\s+([56])U$", source)
    target_match = re.search(
        r"(?m)^#define P14_BRK_TARGET\s+(0[0-7]+)UL$", source)
    assert count_match and target_match, "unknown guest variant"
    count = int(count_match.group(1))
    target = int(target_match.group(1), 8)
    assert "p14_fail('r');" in source
    assert "p14_fail('s');" in source
    assert "p14_fail('c');" not in source
    assert "HALT instruction" in trace, "physical guest not complete"
    trace = trace.replace("\r", "")
    if count == 6:
        assert target in (0o16000, 0o17000)
        match = re.search(r"aaaaa!([rs])", trace)
        assert match, "sixth-child typed failure not observed"
        assert "[B" not in trace[match.start():], "BRK reached unexpectedly"
        if match.group(1) == "r":
            return "sixth RUN returned invalid pid (pre-BRK)"
        return "sixth child did not reach PROC_SLEEP (pre-BRK)"
    assert count == 5 and target == 0o17000
    exact = "aaaaa[B063060/042502]<010000+017000>"
    assert exact in trace, "five-child physical baseline drifted"
    tail = trace.split(exact, 1)[1]
    assert tail.startswith("wwwww\nHALT instruction"), \
        "five-child post-BRK termination shape changed"
    assert "[A" not in tail and "Z" not in tail
    return "five children sleep; BRK does not return; no RAM claim"


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("source", type=Path)
    parser.add_argument("trace", type=Path)
    args = parser.parse_args()
    try:
        result = audit(args.source.read_text(encoding="ascii"),
                       args.trace.read_text(encoding="ascii"))
    except (AssertionError, UnicodeError) as exc:
        parser.exit(1, "FAIL v1624 physical audit: %s\n" % exc)
    print("PASS v1624 negative physical audit: " + result)


if __name__ == "__main__":
    main()
