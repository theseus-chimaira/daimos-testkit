#!/usr/bin/env python3
"""Verify a real PDP-6 KINIT stack watermark and its physical sentinels.

The diagnostic guest uses KINIT_STACK_WATERMARK=1, while a SIMH terminal
breakpoint reads the actual watermark and all 0400 reserved stack words.
No guest-side test probe or external estimate of stack usage is used.
"""

import json
import re
import sys
from pathlib import Path

SENTINEL = int("525252525252", 8)
RESERVE = 256  # default 0400 octal words


def symbol(path, name):
    source = Path(path).read_text(encoding="ascii")
    matches = re.findall(r"^" + re.escape(name) + r"\s+([0-7]+)\s*$",
                         source, re.M)
    if len(matches) != 1:
        raise ValueError("missing/duplicate linked symbol " + name)
    return int(matches[0], 8)


def run(args):
    if len(args) != 6:
        raise ValueError("usage: measure-v1671.py kinit.map kcore.map "
                         "console.clean core_kwords output.json")
    kinit, kcore, log, core_text, output = args[1:]
    core_kwords = int(core_text)
    image_end = symbol(kinit, "__kinit_image_end")
    terminal = symbol(kinit, "vm_enter_initial_user")
    watermark_begin = symbol(kinit, "kinit_stack_watermark_begin")
    watermark_addr = symbol(kcore, "kinit_stack_highwater")
    permanent = symbol(kcore, "sys_resident_words_immediate")
    content = Path(log).read_text(encoding="ascii")

    def breakpoint(name, address):
        marker = r"^Breakpoint, PC:\s+0*%o\b" % address
        if len(re.findall(marker, content, re.M)) != 1:
            raise ValueError("missing/duplicate physical breakpoint " + name)

    breakpoint("sentinel initialization", watermark_begin)
    breakpoint("user-entry terminal", terminal)
    if not re.search(r"^MEM\s+%d K\s*$" % core_kwords, content, re.M) or \
            not re.search(r"^PURE\s+LOADED\s*$", content, re.M):
        raise ValueError("wrong physical memory/PURE boot configuration")
    if "SWAP FAIL" in content or "HALT instruction" in content or \
            "INIT V1" in content or "Goodbye" not in content:
        raise ValueError("unexpected physical boot failure or user execution")
    if image_end + RESERVE > core_kwords * 1024:
        raise ValueError("physical KINIT stack exceeds installed core")

    suffix = re.split(r"^Breakpoint, PC:\s+0*%o\b.*$" % terminal,
                      content, maxsplit=1, flags=re.M)
    if len(suffix) != 2:
        raise ValueError("could not isolate live terminal memory read")
    words = {}
    for addr, value in re.findall(r"^([0-7]{3,7}):\s+([0-7]{12})\s*$",
                                  suffix[1], re.M):
        address = int(addr, 8)
        if address in words:
            raise ValueError("duplicate physical address %o" % address)
        words[address] = int(value, 8)
    for addr in (watermark_addr, permanent):
        if addr not in words:
            raise ValueError("missing terminal hardware word %o" % addr)
    stack = []
    for address in range(image_end, image_end + RESERVE):
        if address not in words:
            raise ValueError("missing real stack cell %o" % address)
        stack.append(words[address])

    highwater = words[watermark_addr]
    if not (0 < highwater < RESERVE):
        raise ValueError("KINIT stack highwater outside safe reserve")
    last_touched = max((index for index, value in enumerate(stack)
                        if value != SENTINEL), default=-1)
    if last_touched != highwater:
        raise ValueError("physical sentinel maximum %d != stored "
                         "watermark %d" % (last_touched, highwater))
    if stack[-1] != SENTINEL or stack[-2] != SENTINEL:
        raise ValueError("KINIT stack reached physical reserve upper bound")
    # A contiguous untouched upper suffix is the structural proof.
    if any(value != SENTINEL for value in stack[highwater + 1:]):
        raise ValueError("corrupt upper pushdown-list sentinel")

    resident_words = words[permanent] & ((1 << 18) - 1)
    if not 0 < resident_words < core_kwords * 1024:
        raise ValueError("invalid installed low resident word count")
    report = {
        "core_kwords": core_kwords,
        "image_end_octal": "%06o" % image_end,
        "stack_reserve_words": RESERVE,
        "stored_highwater_offset": highwater,
        "physical_last_touched_offset": last_touched,
        "minimum_untouched_suffix_words": RESERVE - highwater - 1,
        "low_resident_words": resident_words,
        "terminal_octal": "%06o" % terminal,
    }
    Path(output).write_text(json.dumps(report, indent=2, sort_keys=True)
                            + "\n", encoding="ascii")
    print("PASS v1671 %dK: physical stack highwater offset=%d "
          "of %d; untouched suffix=%d; low resident=%d" %
          (core_kwords, highwater, RESERVE, RESERVE - highwater - 1,
           resident_words))


if __name__ == "__main__":
    try:
        run(sys.argv)
    except (ValueError, OSError) as exc:
        raise SystemExit("FAIL v1671 physical KINIT stack: " + str(exc))
