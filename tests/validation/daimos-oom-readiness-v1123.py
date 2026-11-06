#!/usr/bin/env python3
"""Audit the versioned OOM checklist; fail closed on incomplete gates.

--audit validates the exact inventory and reports unfinished work.
--require-ready returns nonzero while mandatory open items remain.
Neither action enables production OOM or substitutes for guest tests.
"""

import os
from pathlib import Path
import re
import sys


counts = {"S": 8, "A": 4, "B": 7, "C": 4,
          "D": 16, "E": 13, "F": 13, "X": 8}
sections = set("SABCDEF")
post_signoff = {"F12", "F13"}
retired = {"F05"}  # Static 16K fit is tracked outside OOM acceptance.
pattern = re.compile(r"(?m)^- \[([ x])\] ([SABCDEF X][0-9]{2}): ")


def scan(todo):
    begin = "## v1123: fine-grained production OOM enablement checklist"
    if todo.count(begin) != 1:
        raise ValueError("missing/duplicate v1123 checklist heading")
    block = todo.split(begin, 1)[1].split("\n## ", 1)[0]
    found = {}
    for mark, ident in pattern.findall(block):
        if ident in found:
            raise ValueError("duplicate checklist item " + ident)
        found[ident] = mark == "x"
    required = {key + "%02d" % i
                for key, total in counts.items()
                for i in range(1, total + 1)} - retired
    if set(found) != required:
        raise ValueError("missing=" + str(sorted(required - set(found))) +
                         " unexpected=" + str(sorted(set(found) - required)))
    if found["F12"] and any(not found[k] for k in required
                            if k[0] in sections and k not in ("F12", "F13")):
        raise ValueError("production enable F12 precedes prerequisite gates")
    if found["F13"] and not found["F12"]:
        raise ValueError("release commit F13 precedes production enable")
    return found


if len(sys.argv) != 2 or sys.argv[1] not in ("--audit", "--require-ready"):
    raise SystemExit("usage: daimos-oom-readiness-v1123.py "
                     "--audit|--require-ready")

todo = (Path(os.environ["DAIMOS_REPO"]) / "TODO.MD").read_text()
found = scan(todo)

# Require the checker to reject a lost item, a duplicate, a bad mark,
# a premature production enable and an unbacked final release.
start = todo.index("- [x] S01:")
for mutant in (
    todo[:start] + todo[start:].replace("- [x] S01:", "- [x] S00:", 1),
    todo[:start] + "- [x] S01: duplicate\n" + todo[start:],
    todo[:start] + todo[start:].replace("- [x] S01:", "- [!] S01:", 1),
    todo.replace("- [ ] F12:", "- [x] F12:", 1),
    todo.replace("- [ ] F13:", "- [x] F13:", 1),
    todo[:start] + "- [x] F05: retired gate resurrected\n" + todo[start:],
):
    try:
        scan(mutant)
    except ValueError:
        pass
    else:
        raise SystemExit("v1123: unsafe checklist mutation escaped")

mandatory = sorted(k for k, passed in found.items()
                   if k[0] in sections and not passed)
blockers = [k for k in mandatory if k not in post_signoff]
optional = sorted(k for k, passed in found.items()
                  if k.startswith("X") and not passed)
for prefix in "SABCDEFX":
    passed = sum(found[prefix + "%02d" % i]
                 for i in range(1, counts[prefix] + 1)
                 if prefix + "%02d" % i not in retired)
    print("v1123: %s %d/%d checked%s" %
          (prefix, passed, counts[prefix] -
           sum(k.startswith(prefix) for k in retired),
           " (XIP feature excluded)" if prefix == "X" else ""))
print("v1123: mandatory OPEN=" + str(len(mandatory)) +
      " optional-XIP OPEN=" + str(len(optional)))
print("v1123: pre-activation OPEN=" + str(len(blockers)) +
      " post-signoff actions remaining=" +
      str(sum(not found[k] for k in post_signoff)))
print("v1123: pre-activation open IDs=" + ",".join(blockers))
if blockers:
    print("v1123: OOM ACTIVATION BLOCKED; production flag must remain 0")
    if sys.argv[1] == "--require-ready":
        raise SystemExit(2)
else:
    print("v1123: pre-enable checklist complete; independent review "
          "required before F12, then run post-enable tests and F13")
print("v1273: checklist inventory and six unsafe mutations PASS")
