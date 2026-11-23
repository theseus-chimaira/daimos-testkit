#!/usr/bin/env python3
"""Extend original v1681 full native PDP6 finalizer with TWO actual MM owners."""

from pathlib import Path
import sys


def once(text, old, new):
    if text.count(old) != 1:
        raise ValueError("v1900 original native finalizer fixture drift: " + old[:70])
    return text.replace(old, new, 1)


def prepare(work):
    path = work / "test-fixture.s"
    old = path.read_text(encoding="ascii")
    changed = once(old,
        "        movei 1,1\n        movem 1,mm_extent_count\n"
        "        move 1,[01400,,050400]\n",
        "        movei 1,2\n        movem 1,mm_extent_count\n"
        "        move 1,[01400,,050400]\n")
    changed = once(changed,
        "        move 1,[4,,2]\n        movem 1,mm_extents+1\n"
        "        movei 1,050400\n",
        "        move 1,[4,,2]\n        movem 1,mm_extents+1\n"
        "        ; v1900: exact complete provisional PROCESS target\n"
        "        ; still owned by slot2 after an original FULL refusal.\n"
        "        move 1,[02000,,060000]\n"
        "        movem 1,mm_extents+2\n"
        "        move 1,[1,,2]\n"
        "        movem 1,mm_extents+3\n"
        "        movei 1,050400\n")
    changed = once(changed,
        "        move 1,mm_extent_count\n        caie 1,1\n"
        "        jrst fail_9_v1681\n",
        "        move 1,mm_extent_count\n        caie 1,2\n"
        "        jrst fail_9_v1681\n")
    changed = once(changed,
        "        move 1,mm_extents+1\n"
        "        came 1,[014,,2]         ; exact original type + PIN=1 + owner\n"
        "        jrst fail_10_v1681\n",
        "        move 1,mm_extents+1\n"
        "        came 1,[014,,2]         ; exact original type + PIN=1 + owner\n"
        "        jrst fail_10_v1681\n"
        "        move 1,mm_extents+2\n"
        "        came 1,[02000,,060000]\n"
        "        jrst fail_10_v1681\n"
        "        move 1,mm_extents+3\n"
        "        came 1,[1,,2]\n"
        "        jrst fail_10_v1681\n")
    changed = once(changed,
        "        move 1,mm_extents+1\n"
        "        came 1,[014,,2]\n"
        "        jrst fail_14_v1681\n",
        "        move 1,mm_extents+1\n"
        "        came 1,[014,,2]\n"
        "        jrst fail_14_v1681\n"
        "        move 1,mm_extents+2\n"
        "        came 1,[02000,,060000]\n"
        "        jrst fail_14_v1681\n"
        "        move 1,mm_extents+3\n"
        "        came 1,[1,,2]\n"
        "        jrst fail_14_v1681\n")
    if changed == old or changed.count("v1900: exact complete") != 1:
        raise ValueError("v1900 native two-owner test did not change")
    path.write_text(changed, encoding="ascii")
    print("v1900: actual original MM source pin and extra full PROCESS owner")
    print("v1900: original idle FINALIZE+PREVM retries, then frees both")


if __name__ == "__main__":
    if len(sys.argv) != 2:
        raise SystemExit("usage: prepare-finalizer-v1900.py native-workdir")
    try:
        prepare(Path(sys.argv[1]))
    except (OSError, ValueError) as exc:
        raise SystemExit("FAIL v1900 actual MM source-linked finalizer: " + str(exc))
