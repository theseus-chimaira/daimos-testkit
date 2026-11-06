#!/usr/bin/env python3
"""Check that asynchronous provider I/O cannot alias slot-0 swap scratch.

The native simulator still supplies the runtime evidence; this source guard
prevents reintroducing the known shared-buffer ownership violation.
"""

from pathlib import Path
import sys


def check(source):
    exchange = source.split('proc_swap_exchange_sector_v771:', 1)[1]
    exchange = exchange.split('proc_swap_exchange_overlap_v772:', 1)[0]
    instructions = '\n'.join(line.split(';', 1)[0] for line in
                             exchange.splitlines())
    if 'fs_block_workspace' in instructions:
        raise ValueError('swap exchange aliases filesystem I/O workspace')
    if 'bcache_workspace_invalidate' in instructions:
        raise ValueError('swap exchange must not mutate filesystem cache')
    if 'movei   3,proc_swap_sector_buffer_v1237' not in instructions:
        raise ValueError('swap disk read is not directed to private scratch')
    if 'hrli    1,proc_swap_sector_buffer_v1237' not in instructions:
        raise ValueError('swap restore is not sourced from private scratch')
    if ('proc_swap_sector_buffer_v1237:\n'
            '        .block  0200') not in source:
        raise ValueError('missing exact 128-word owned swap buffer')


def main():
    if len(sys.argv) != 2:
        raise SystemExit('usage: v1237 PROC_SWAP_PDP6.S')
    source = Path(sys.argv[1]).read_text()
    check(source)
    # Negative control must fail for the original shared scratch address.
    mutant = source.replace('movei   3,proc_swap_sector_buffer_v1237',
                            'movei   3,fs_block_workspace', 1)
    try:
        check(mutant)
    except ValueError:
        pass
    else:
        raise ValueError('workspace-alias negative control unexpectedly passed')
    print('v1237: dedicated swap scratch and alias mutant PASS')


if __name__ == '__main__':
    main()
