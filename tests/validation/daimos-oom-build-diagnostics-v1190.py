#!/usr/bin/env python3
"""Fail closed on unexpected KCC/assembler or release-media diagnostics.

This is an audit of complete v1174 release-media build logs.  The legacy
note allowlist is exact; it does not suppress warnings in the compiler or
the build.  Diagnostics outside the approved list fail the audit.
"""

import re
import sys
import tarfile
from pathlib import Path


KNOWN_NOTES = {
    ('boot/tsfs_boot.h', 'Identifer truncated: "tsfs_boot_selected_unit_mask_v2"'),
    ('proc/proc_packed_v1.h',
     'Identifer truncated: "proc_packed_evict_transaction_v"'),
    ('proc/proc_packed_v1.h',
     'Identifer truncated: "proc_packed_restore_transaction"'),
    ('proc/proc_storage_map_v28.h',
     'Identifer truncated: "PROC_STORAGE_MAP_SLOTS_PER_WORD"'),
    ('das.c', 'Parameter "msg" not used'),
    ('das_native1.c', 'Static object "das_native_stderr" never used'),
    ('das_native2.c', 'Static object "das_native_stderr" never used'),
    ('exec/commands.c', 'Static function "cmd_err" never used'),
    ('exec/commands.c', 'Static function "cmd_record_words" never used'),
    ('exec/utility.c', 'Static function "util_cmd_bc" never used'),
    ('exec/utility.c', 'Static function "util_cmd_expr" never used'),
    ('modules/module_minit.c',
     'Static object "dtfs_runtime_dir_ptr" never used, not emitted'),
}

LEGACY_WARNING = (
    'mkd6fs: warning: legacy D6FSR2 layout lacks explicit reserved ranges'
)


def require(ok, message):
    if not ok:
        raise SystemExit('v1190: ' + message)


def member(archive, path):
    content = archive.extractfile('./' + path)
    require(content is not None, 'missing archive member ' + path)
    return content.read().decode('utf-8', errors='replace')


def check_profile(archive, mode):
    lines = member(archive, mode + '/profile.txt').splitlines()
    profile = dict(line.split('=', 1) for line in lines if '=' in line)
    require(profile.get('production_oom') == 'OFF',
            mode + ' has production OOM enabled')
    require(profile.get('mode') == str(int(mode == 'enabled')),
            mode + ' mismatched test-only mode')


def check_log(log, archive_name, mode):
    counts = {}
    for lineno, line in enumerate(log.splitlines(), 1):
        match = re.match(
            r'^"([^"]+)", line [0-9]+: \[Note\] (.*)$', line)
        if match is not None:
            item = (match.group(1), match.group(2))
            require(item in KNOWN_NOTES,
                    '%s %s unknown KCC note at %d: %s' %
                    (archive_name, mode, lineno, line))
            counts[item] = counts.get(item, 0) + 1
            continue
        if line == LEGACY_WARNING:
            counts[('legacy', 'd6fsr2')] = (
                counts.get(('legacy', 'd6fsr2'), 0) + 1)
            continue
        if re.search(r'(?i)(\[warning\]|\[error\]|warning:|error:|'
                     r'undefined reference|implicit declaration|'
                     r'assembler fatal|fatal error)', line):
            raise SystemExit(
                'v1190: %s %s unexpected diagnostic at line %d: %s' %
                (archive_name, mode, lineno, line))
    require(('legacy', 'd6fsr2') in counts,
            '%s %s legacy D6FS warning disappeared unexpectedly' %
            (archive_name, mode))
    expected_truncations = {
        (source, diagnostic) for source, diagnostic in KNOWN_NOTES
        if diagnostic.startswith('Identifer truncated')
    }
    require(expected_truncations.issubset(counts),
            '%s %s expected KCC long-identifier notes missing' %
            (archive_name, mode))
    require('d6fsck: selected superblock' in log and 'state=CLEAN' in log,
            '%s %s missing clean D6FS check' % (archive_name, mode))
    return counts


def main():
    if sys.argv[1:] == ['--self-test']:
        baseline = '\n'.join(
            '"%s", line 1: [Note] %s' % (source, note)
            for source, note in sorted(KNOWN_NOTES))
        baseline += '\n' + LEGACY_WARNING
        baseline += '\nd6fsck: selected superblock 0 seq=1 state=CLEAN\n'
        require(check_log(baseline, 'self-test', 'disabled'),
                'known diagnostic baseline not accepted')
        for mutant in (
                '[Warning] silent code generation error',
                'compiler: error: unexpected error',
                '"foo.c", line 2: [Note] new unexpected warning'):
            try:
                check_log(baseline + '\n' + mutant, 'self-test', 'disabled')
            except SystemExit:
                continue
            raise SystemExit('v1190: negative diagnostic mutant passed: ' +
                             mutant)
        print('v1190: three unexpected diagnostic mutants rejected PASS')
        return
    require(len(sys.argv) == 3,
            'usage: daimos-oom-build-diagnostics-v1190.py '
            'ANDROID_EVIDENCE_TAR LINUX_EVIDENCE_TAR')
    reference = None
    for pathname in sys.argv[1:]:
        with tarfile.open(pathname, 'r:gz') as archive:
            for mode in ('disabled', 'enabled'):
                check_profile(archive, mode)
                notes = check_log(member(archive, mode + '/build.log'),
                                  Path(pathname).name, mode)
                known = set(notes)
                if reference is not None:
                    require(known == reference,
                            'diagnostic classes differ across hosts/policies')
                else:
                    reference = known
                print('v1190: %s %s known diagnostic classes=%d '
                      'unexpected=0 PASS' %
                      (Path(pathname).name, mode, len(notes)))
    print('v1190: 4 complete release-media builds, no unexplained '
          'compiler/assembler diagnostics PASS')


if __name__ == '__main__':
    main()
