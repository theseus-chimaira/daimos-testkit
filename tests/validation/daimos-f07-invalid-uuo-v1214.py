#!/usr/bin/env python3
"""Stop a disposable PDP-6 guest at its first invalid monitor UUO.

The permanent trap handler already saves the trapped instruction and the
user return PC. Halt only after those saves, before the diagnostic CTY
output can obscure the failure. No production kernel source is modified.
"""

from pathlib import Path
import sys


def inject(root):
    path = root / 'proc/mach_user_pdp6.s'
    source = path.read_text()
    start = source.index('mach_syscall_invalid:\n')
    end = source.index('\nmach_invalid_putchar:', start)
    region = source[start:end]
    anchor = '        movem 1,mach_invalid_uuo_pc\n'
    if region.count(anchor) != 1:
        raise ValueError('v1214: invalid-UUO saved-PC anchor moved')
    region = region.replace(anchor, anchor +
        '        ; v1214 disposable-only trap state capture.\n'
        '        halt 7\n', 1)
    path.write_text(source[:start] + region + source[end:])


if __name__ == '__main__':
    if len(sys.argv) != 2:
        raise SystemExit('usage: invalid-uuo-v1214.py KERNEL_ROOT')
    inject(Path(sys.argv[1]))
