#!/usr/bin/env python3
"""Add two disposable user-side F07 BRK milestones without kernel edits.

The requester emits '&' after its release PIPE read and immediately before
the physical pressure BRK, then '=' as soon as that syscall returns. The
OOM-enabled test must never print '='. Neither stage changes the result.
"""

from pathlib import Path
import sys


def replace_once(text, old, new):
    if text.count(old) != 1:
        raise ValueError('v1259: missing or ambiguous requester anchor')
    return text.replace(old, new, 1)


def inject(text):
    text = replace_once(text, '''                if (argv[1][1] ==
                    TEST_SIX6('O', ' ', ' ', ' ', ' ', ' ')) {
''', '''                if (argv[1][1] ==
                    TEST_SIX6('O', ' ', ' ', ' ', ' ', ' ')) {
                        kword_t v1259_brk_result;
''')
    text = replace_once(text, '''                        if (dsys_brk(V1075_BRK_REQUEST) !=
                            (kword_t)-1L)
                                (void)dsys_exit(071);
''', '''                        (void)dsys_writechar(1, '&');
                        v1259_brk_result = dsys_brk(V1075_BRK_REQUEST);
                        (void)dsys_writechar(1, '=');
                        if (v1259_brk_result != (kword_t)-1L)
                                (void)dsys_exit(071);
''')
    return text


if __name__ == '__main__':
    if len(sys.argv) != 3:
        raise SystemExit('usage: v1259 SOURCE_C DISPOSABLE_DESTINATION_C')
    source, target = map(Path, sys.argv[1:])
    if target.exists():
        raise SystemExit('v1259: refusing to overwrite disposable source')
    target.write_text(inject(source.read_text()))
