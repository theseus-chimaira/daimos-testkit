#!/usr/bin/env python3
"""Identify the D6FS provider failure beneath a rejected EXEC payload.

All counters live in disposable KCORE. No additional stack frames,
register changes, block-cache changes or permanent kernel data.
"""

from pathlib import Path
import sys


FIELDS = ('provider_calls', 'requested', 'vnode', 'provider_bad_fcb',
          'reader_fail', 'block_io_fail', 'position', 'done',
          'target', 'provider_result')


def inject(root):
    path = root / 'fs/d6fs_runtime.s'
    source = path.read_text()
    changes = (
        ('d6fs_provider_read_words:\n',
         'd6fs_provider_read_words:\n'
         '        aos     daimos_f07d_provider_calls_v1231\n'
         '        movem   1,daimos_f07d_vnode_v1231\n'
         '        movem   4,daimos_f07d_requested_v1231\n'),
        ('d6fs_provider_read_words_fail:\n',
         'd6fs_provider_read_words_fail:\n'
         '        aos     daimos_f07d_provider_bad_fcb_v1231\n'),
        ('d6fs_reader_rw_fail:\n',
         'd6fs_reader_rw_fail:\n'
         '        aos     daimos_f07d_reader_fail_v1231\n'
         '        movem   016,daimos_f07d_position_v1231\n'
         '        movem   015,daimos_f07d_done_v1231\n'
         '        movem   014,daimos_f07d_target_v1231\n'),
        ('d6fs_get_block_read_fail:\n',
         'd6fs_get_block_read_fail:\n'
         '        aos     daimos_f07d_block_io_fail_v1231\n'),
        ('d6fs_provider_read_words_done:\n',
         'd6fs_provider_read_words_done:\n'
         '        movem   1,daimos_f07d_provider_result_v1231\n'),
    )
    for old, new in changes:
        if source.count(old) != 1:
            raise ValueError('v1231: D6FS entry moved: ' + old.strip())
        source = source.replace(old, new, 1)
    for field in FIELDS:
        source = ('        .globl daimos_f07d_%s_v1231\n' % field) + source
    path.write_text(source)
    core = root / 'proc/proc_pdp6.s'
    source = core.read_text() + '\n        .bss\n'
    for field in FIELDS:
        sym = 'daimos_f07d_%s_v1231' % field
        source += '        .globl %s\n%s: .block 1\n' % (sym, sym)
    core.write_text(source)


if __name__ == '__main__':
    if len(sys.argv) != 2:
        raise SystemExit('usage: v1231 DISPOSABLE_KERNEL')
    inject(Path(sys.argv[1]))
