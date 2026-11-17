#!/usr/bin/env python3
"""Extract the original, unmodified PDP-6 PURE owner guard leaves.

This only supplies the established assembler constants to the standalone
native fixture.  No guard instructions, owner conditions, or PIC are
modified in the passing build.
"""

from pathlib import Path
import sys


def guard(source, output, mutation):
    text = Path(source).read_text(encoding="ascii")
    marker = "proc_swap_backing_busy:\n"
    assert text.count(marker) == 1
    body = text.split(marker, 1)[1]
    assert body.count("proc_swap_mount_busy:\n") == 1
    body = marker + body
    intro = (
        ".text\n"
        ".globl proc_swap_backing_busy\n"
        ".globl proc_swap_mount_busy\n"
        ".equ PROC_SWAP_BACKING_OFFSET,0406\n"
        ".equ PROC_SWAP_MOUNT_SHIFT,022\n"
        ".equ PROC_SWAP_TEXT_SHIFT,026\n"
        ".equ PROC_SWAP_TEXT_MASK,037777\n"
    )
    if mutation == "mount":
        before = "        jumpe   3,proc_swap_mount_busy_next"
        after = "        jumpn   3,proc_swap_mount_busy_next"
    elif mutation == "backing":
        before = ("        camn    1,10\n"
                  "        jrst    proc_swap_backing_is_busy")
        after = ("        came    1,10\n"
                 "        jrst    proc_swap_backing_is_busy")
    elif mutation == "none":
        before = after = ""
    else:
        raise ValueError("unsupported mutation: " + mutation)
    if before:
        assert body.count(before) == 1
        body = body.replace(before, after, 1)
    Path(output).write_text(intro + body, encoding="ascii")


if __name__ == "__main__":
    if len(sys.argv) != 4:
        raise SystemExit("usage: extract-guard-v1649.py original.s result.s mutation")
    guard(sys.argv[1], sys.argv[2], sys.argv[3])
