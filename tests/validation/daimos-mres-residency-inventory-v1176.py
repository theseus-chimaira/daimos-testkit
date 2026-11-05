#!/usr/bin/env python3
"""Reconcile the DSK/D6FS MINIT resident set with live PDP-6 memory.

The installed module names below follow the full 256K DSK/D6FS
MINIT table and its observed boot decisions.  This is deliberately
profile-specific: a tape, no-DRM, lowmem, or GUI boot needs its own
derived set.  Compare the sum to the real SYS_MEMINFO-based MRES
residency, not to the sum of all linked MRES packages.
"""

from pathlib import Path
import re
import sys
import tarfile


INSTALLED_V1176 = (
    'cty', 'clk', 'pclk', 'monitorfs',
    'ptr', 'ptp', 'lpt', 'cr', 'cp', 'dcs', 'ge', 'dpy',
    'tty', 'ocnsls', 'dsk', 'drm', 'swapv481',
    'blockset', 'logstore', 'memfs', 'slv', 'd6fs',
)
OPTIONAL_INPUT_V1176 = ('ptr', 'ptp', 'lpt', 'cr', 'cp',
                        'dcs', 'ge', 'dpy', 'slv')
LARGE_V1176 = ('d6fs', 'memfs', 'monitorfs', 'swapv481')


def require(condition, message):
    if not condition:
        raise SystemExit('v1176: ' + message)


def member(archive, mode, name):
    f = archive.extractfile('./%s/%s' % (mode, name))
    require(f is not None, 'missing %s %s' % (mode, name))
    return f.read().decode('utf-8', errors='replace')


def verify(archive, mode):
    inv = member(archive, mode, 'mres-packages-v1174.txt')
    sizes = {}
    for name, value in re.findall(
            r'(?m)^([a-z0-9]+)-mres\.dobj mres: '
            r'initialized=\d+ bss=\d+ resident=(\d+)$', inv):
        require(name not in sizes, 'duplicate package ' + name)
        sizes[name] = int(value)
    require(len(sizes) >= len(INSTALLED_V1176),
            'incomplete MRES package inventory')
    require(all(name in sizes for name in INSTALLED_V1176),
            'expected MINIT module package missing')

    report = member(archive, mode, 'residency-v1174.txt')
    match = re.search(r'actually installed permanent MRES images=(\d+)',
                      report)
    require(match is not None, 'live MRES measurement missing')
    live_mres = int(match.group(1))
    installed = sum(sizes[name] for name in INSTALLED_V1176)
    require(installed == live_mres,
            'MINIT module sum %d differs from real live MRES %d' %
            (installed, live_mres))

    boot = member(archive, mode, 'simh.out')
    for marker in ('CTY', 'PCLK', 'DSK270', 'DRM236', 'BSET',
                   'LOGSTR', 'MEMFS', 'D6FS'):
        require(re.search(r'(?m)^' + marker + r'\s+', boot),
                'boot marker missing: ' + marker)
    optional = sum(sizes[name] for name in OPTIONAL_INPUT_V1176)
    large = sum(sizes[name] for name in LARGE_V1176)
    print('v1176: %s: %d installed MRES packages = %d live words PASS' %
          (mode, len(INSTALLED_V1176), live_mres))
    print('v1176: %s: D6FS+MEMFS+MonitorFS+swap = %d words' %
          (mode, large))
    print('v1176: %s: optional PTR/PTP/LPT/CR/CP/DCS/GE/DPY/SLV = '
          '%d words (not enough to remove the 16K deficit)' %
          (mode, optional))
    print('v1176: %s: excluded linked package names = %s' %
          (mode, ','.join(sorted(set(sizes) - set(INSTALLED_V1176)))))
    return sizes


def main():
    require(len(sys.argv) == 2, 'usage: AUDIT v1174-archive.tar.gz')
    with tarfile.open(sys.argv[1], 'r:gz') as archive:
        disabled = verify(archive, 'disabled')
        enabled = verify(archive, 'enabled')
    require(disabled == enabled,
            'installed module sizes vary within one host/policy pair')
    print('v1176: both policies reconcile exactly with MINIT residency PASS')


if __name__ == '__main__':
    main()
