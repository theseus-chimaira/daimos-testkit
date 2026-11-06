#!/usr/bin/env python3
"""Increase only the disposable PDP-6 idle/swap stack for F07 diagnosis.

This is a controlled experiment, not a production fix. Keep the C boot
allocator and assembler watermark bound in sync; a mismatch invalidates
both the memory budget and all reported stack high-water values.
"""

from pathlib import Path
import os
import sys


def replace_one(path, old, new):
    src = path.read_text()
    if src.count(old) != 1:
        raise ValueError('v1225: idle-stack definition changed: ' + str(path))
    path.write_text(src.replace(old, new, 1))


def inject(root):
    size = os.environ.get('V1225_IDLE_STACK_WORDS', '0140')
    if size not in ('0140', '0200', '0300', '0400'):
        raise ValueError('v1225: unsupported diagnostic stack size')
    # Accept archived 0100-word test sources and the corrected 0400-word
    # production reserve. A matching override needs no source edit.
    header = root / 'boot/kinit.h'
    asm = root / 'proc/proc_pdp6.s'
    for old in ('00100UL', '00400UL'):
        original = '#define KERNEL_IDLE_STACK_WORDS   ' + old
        if original in header.read_text():
            replace_one(header, original,
                        '#define KERNEL_IDLE_STACK_WORDS   0%sUL' % size)
            break
    else:
        raise ValueError('v1225: boot stack definition changed')
    for old in ('0100', '0400'):
        original = '        .equ    KERNEL_IDLE_STACK_WORDS,' + old
        if original in asm.read_text():
            replace_one(asm, original,
                        '        .equ    KERNEL_IDLE_STACK_WORDS,%s' % size)
            break
    else:
        raise ValueError('v1225: native stack definition changed')


if __name__ == '__main__':
    if len(sys.argv) != 2:
        raise SystemExit('usage: v1225 DISPOSABLE_KERNEL')
    inject(Path(sys.argv[1]))
