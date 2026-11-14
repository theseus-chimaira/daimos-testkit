#!/usr/bin/env python3
"""v1559: enforce DTFS native data/metadata write-veneer coverage.

This is a source boundary regression, not a replacement for physical PDP-6
fault injection. A new DTFS write call must not bypass the centralized
read-only V2 refusal and future DIRTY-before-data transaction.
"""

import argparse
from pathlib import Path
import re


def check(root):
    fs = root / 'system' / 'kernel' / 'fs'
    failures = []
    covered = []
    for path in sorted(fs.glob('dtfs*.s')):
        text = path.read_text()
        for lineno, line in enumerate(text.splitlines(), 1):
            code = line.split(';', 1)[0]
            match = re.search(r'\bpushj\s+17\s*,\s*(dtfs_dtc_write(?:_jump)?)\b',
                              code, re.IGNORECASE)
            if not match:
                continue
            callee = match.group(1).lower()
            relative = str(path.relative_to(root))
            if callee == 'dtfs_dtc_write_jump':
                # The physical RBN0 write-ahead service must bypass the
                # data veneer, otherwise it recursively arms itself.
                if path.name not in ('dtfs_intent_arm_v1551.s',
                                     'dtfs_runtime.s'):
                    failures.append('%s:%d: unexpected raw DTC WRITE' %
                                    (relative, lineno))
                else:
                    kind = ('raw-intent-only' if path.name ==
                            'dtfs_intent_arm_v1551.s' else 'raw-veneer-only')
                    covered.append((relative, lineno, kind))
            else:
                covered.append((relative, lineno, 'guarded-data'))

    c = (fs / 'dtfs.c').read_text()
    for match in re.finditer(r'\bdtfs_dtc_write\s*\(', c):
        covered.append(('system/kernel/fs/dtfs.c',
                        c.count('\n', 0, match.start()) + 1, 'guarded-data'))

    runtime = (fs / 'dtfs_runtime.s').read_text()
    guard = runtime.split('dtfs_dtc_write:', 1)
    if len(guard) != 2:
        failures.append('missing common dtfs_dtc_write veneer')
    else:
        entry = guard[1].split('dtfs_dtc_write_jump:', 1)[0]
        if not re.search(r'pushj\s+17\s*,\s*dtfs_v2_ro_write_guard_v1555', entry):
            failures.append('missing common V2 physical-unit write refusal')
        if not re.search(r'jumpn\s+1\s*,\s*dtfs_dtc_write_v2_refuse_v1555', entry):
            failures.append('V2 refusal does not branch on guard failure')
        if not re.search(r'pushj\s+17\s*,\s*dtfs_dtc_write_jump', entry):
            failures.append('common veneer no longer invokes raw DTC')

    names = {Path(p).name for p, _, kind in covered if kind == 'guarded-data'}
    expected = {'dtfs.c', 'dtfs_runtime.s', 'dtfs_chain_walk.s', 'dtfs_resize.s'}
    if not expected.issubset(names):
        failures.append('missing expected native data/metadata writers: %s' %
                        ','.join(sorted(expected - names)))
    if not any(kind == 'raw-intent-only' for _, _, kind in covered):
        failures.append('missing separate raw write-ahead marker path')
    if failures:
        raise AssertionError('; '.join(failures))
    return covered


def mutation_tests(root):
    """Mutate source in-memory, with no modifications to the checkout."""
    import tempfile
    import shutil

    fs = root / 'system' / 'kernel' / 'fs'
    with tempfile.TemporaryDirectory(prefix='daimos-dtfs-v1559-') as tmp:
        target = Path(tmp) / 'system' / 'kernel' / 'fs'
        target.mkdir(parents=True)
        for name in ('dtfs.c', 'dtfs_runtime.s', 'dtfs_chain_walk.s',
                     'dtfs_resize.s', 'dtfs_intent_arm_v1551.s'):
            shutil.copyfile(fs / name, target / name)
        mutants = (
            ('chain-raw-bypass', 'dtfs_chain_walk.s',
             'pushj 17,dtfs_dtc_write', 'pushj 17,dtfs_dtc_write_jump'),
            ('resize-raw-bypass', 'dtfs_resize.s',
             'pushj 17,dtfs_dtc_write', 'pushj 17,dtfs_dtc_write_jump'),
            ('runtime-guard-bypass', 'dtfs_runtime.s',
             'pushj   17,dtfs_v2_ro_write_guard_v1555',
             'pushj   17,bcache_invalidate_all'),
            ('runtime-refusal-bypass', 'dtfs_runtime.s',
             'jumpn   1,dtfs_dtc_write_v2_refuse_v1555',
             'jumpe   1,dtfs_dtc_write_v2_refuse_v1555'),
            ('intent-recursive-write', 'dtfs_intent_arm_v1551.s',
             'pushj   17,dtfs_dtc_write_jump',
             'pushj   17,dtfs_dtc_write'),
        )
        for label, name, before, after in mutants:
            path = target / name
            original = path.read_text()
            assert original.count(before) >= 1, (label, original.count(before))
            path.write_text(original.replace(before, after, 1))
            try:
                check(Path(tmp))
            except AssertionError:
                print('PASS v1559: rejected %s' % label)
            else:
                raise AssertionError('unsafe source mutation accepted: %s' % label)
            path.write_text(original)
    return len(mutants)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('repo', type=Path)
    args = parser.parse_args()
    covered = check(args.repo)
    print('PASS v1559: %d actual DTFS guarded/raw callsites audited' %
          len(covered))
    count = mutation_tests(args.repo)
    print('PASS v1559: %d unsafe source mutations rejected' % count)


if __name__ == '__main__':
    main()
