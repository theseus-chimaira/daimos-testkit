#!/usr/bin/env python3
"""Locate the exact EXEC loader phase rejecting a stressed RUN child.

Test-only KCORE counters. All touched instructions are otherwise
unchanged; no registers, process states or stack frames are modified.
Phases: 1 lookup, 2 stat, 3 access, 4 header, 5 VM allocation,
6 image read/decode, 7 swap attachment. A phase is entered before
its operation, so the final recorded phase identifies the failure.
"""

from pathlib import Path
import sys


def inject(root):
    path = root / 'proc/exec_load.s'
    src = path.read_text()
    begin = 'exec_load_process:\n'
    if src.count(begin) != 1:
        raise ValueError('v1229: loader entry changed')
    src = src.replace(begin, begin +
                      '        setzm   daimos_f07e_phase_v1229\n'
                      '        aos     daimos_f07e_calls_v1229\n', 1)
    # Set the phase without modifying any AC, including the request
    # registers and the original first failure return value.
    for label, anchor in (
        ('lookup', '        pushj   17,file_lookup_path\n'),
        ('stat', '        pushj   17,vfs_stat\n'),
        ('access', '        pushj   17,file_check_access\n'),
        ('header', 'exec_load_read_header:\n'),
        ('vm', 'exec_load_create_vm:\n'),
        ('image', 'exec_load_plain_image:\n'),
        ('attach', 'exec_load_attach:\n')):
        if src.count(anchor) != 1:
            raise ValueError('v1229: loader phase changed: ' + label)
        if label in ('header', 'vm', 'image', 'attach'):
            # These are labels reached through conditional branches.
            replacement = anchor + '        aos     daimos_f07e_phase_v1229\n'
        else:
            replacement = '        aos     daimos_f07e_phase_v1229\n' + anchor
        src = src.replace(anchor, replacement, 1)
    # The compressed-image branch bypasses the plain-image label.
    anchor = '        pushj   17,d6lz36_decode_vfs\n'
    if src.count(anchor) != 1:
        raise ValueError('v1229: compressed image decode moved')
    src = src.replace(anchor,
                      '        aos     daimos_f07e_phase_v1229\n' + anchor, 1)
    for symbol in ('phase', 'calls'):
        src = ('        .globl daimos_f07e_%s_v1229\n' % symbol) + src
    path.write_text(src)
    core = root / 'proc/proc_pdp6.s'
    text = core.read_text() + '\n        .bss\n'
    for field in ('phase', 'calls'):
        sym = 'daimos_f07e_%s_v1229' % field
        text += '        .globl %s\n%s: .block 1\n' % (sym, sym)
    core.write_text(text)


if __name__ == '__main__':
    if len(sys.argv) != 2:
        raise SystemExit('usage: v1229 DISPOSABLE_KERNEL')
    inject(Path(sys.argv[1]))
