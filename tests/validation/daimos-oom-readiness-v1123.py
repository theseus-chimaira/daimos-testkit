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
HEADING = "## v1123: fine-grained production OOM enablement checklist"


def active_block(todo):
    if todo.count(HEADING) != 1:
        raise ValueError("missing/duplicate v1123 checklist heading")
    begin = todo.index(HEADING) + len(HEADING)
    end = todo.find("\n## ", begin)
    if end < 0:
        end = len(todo)
    return begin, end


def change_active(todo, changes):
    """Mutate only the authoritative checklist, never historical TODOs."""
    begin, end = active_block(todo)
    block = todo[begin:end]
    for old, new in changes:
        if block.count(old) != 1:
            raise ValueError("mutation anchor not unique " + old)
        block = block.replace(old, new, 1)
    return todo[:begin] + block + todo[end:]


def scan(todo):
    begin, end = active_block(todo)
    block = todo[begin:end]
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

# The actual switch and release gates may already be checked during
# F12/F13, so create invalid dependency states explicitly in the
# active checklist. Never mutate historical status summaries first.
f11_old = "- [x] F11:" if found["F11"] else "- [ ] F11:"
f12_old = "- [x] F12:" if found["F12"] else "- [ ] F12:"
f13_old = "- [x] F13:" if found["F13"] else "- [ ] F13:"
for mutant in (
    change_active(todo, [("- [x] S01:", "- [x] S00:")]),
    change_active(todo, [("- [x] S01:",
                          "- [x] S01: duplicate\n- [x] S01:")]),
    change_active(todo, [("- [x] S01:", "- [!] S01:")]),
    change_active(todo, [(f11_old, "- [ ] F11:"),
                         (f12_old, "- [x] F12:")]),
    change_active(todo, [(f12_old, "- [ ] F12:"),
                         (f13_old, "- [x] F13:")]),
    change_active(todo, [("- [x] S01:",
                          "- [x] F05: retired gate resurrected\n- [x] S01:")]),
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
print("v1284: active checklist inventory and six unsafe mutations PASS")
