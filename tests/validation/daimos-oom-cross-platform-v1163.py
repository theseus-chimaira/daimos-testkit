#!/usr/bin/env python3
"""Compare complete v1160 E13 evidence from two independent PDP-6 hosts.

This is an evidence cross-check, not authorization to enable OOM. The
full mandatory checklist, actual production resident MRES and exact
final-candidate revision remain separate gates.
"""

import os
import re
import sys
import tarfile


def check(condition, message):
    if not condition:
        raise SystemExit('v1163: ' + message)


def content(archive, mode, name):
    member = archive.extractfile('./%s/%s' % (mode, name))
    check(member is not None, 'missing %s/%s' % (mode, name))
    return member.read().decode('utf-8', errors='replace')


def kv(text):
    return dict(line.split('=', 1) for line in text.splitlines()
                if '=' in line)


def counters(addresses, simh):
    result = {}
    for line in addresses.splitlines():
        name, addr = line.split()
        expression = (r'(?m)^\s*0*' + re.escape(addr.lstrip('0') or '0')
                      + r'\s*:\s*([0-7]+)')
        found = re.findall(expression, simh)
        check(len(found) == 1, 'counter missing/duplicate: ' + name)
        result[name] = int(found[0], 8)
    return result


def inspect(path, host):
    result = {}
    expected_policy = os.environ.get('V1283_PRODUCTION_OOM_DEFAULT', '0')
    check(expected_policy in ('0', '1'), 'invalid production OOM expectation')
    with tarfile.open(path, 'r:gz') as archive:
        for mode in ('disabled', 'enabled'):
            profile = kv(content(archive, mode, 'profile.txt'))
            expected = {
                'mode': str(int(mode == 'enabled')),
                'boot': 'dsk', 'root': 'disk', 'rootset': '1',
                'profile': 'full', 'core_octal': '01000000',
                'simulator_kwords': '256', 'compiler': 'kcc',
                'pclk': 'REALTIME', 'wall_clock_hz': '60',
                'production_oom': ('ON' if expected_policy == '1' else 'OFF'),
            }
            for key, value in expected.items():
                check(profile.get(key) == value,
                      '%s %s: wrong %s' % (host, mode, key))
            boot = content(archive, mode, 'boot.ini')
            for command in ('set cpu 256k', 'deposit SW 1',
                            'set pclk REALTIME', 'set wcnsls disabled',
                            'set ocnsls disabled', 'attach -q dsk0 ',
                            'attach -q dr0 '):
                check(command in boot, '%s %s: missing boot %s' %
                      (host, mode, command))
            simh = content(archive, mode, 'simh.out')
            check('PDP6 simulator Open SIMH V4.1-0' in simh and
                  'MEM                                 256 K' in simh and
                  'D6FS' in simh and 'LOADED' in simh and
                  ('<KWP' if mode == 'enabled' else '<DNWP') in simh,
                  '%s %s: missing complete boot/terminal markers' %
                  (host, mode))
            seen = counters(content(archive, mode, 'addresses'), simh)
            exact = {
                'holder_enter': 1, 'holder_return': 1,
                'holder_lease': 7 << 18, 'lease_at_oom': 7 << 18,
                'real_oom': 1, 'error': 0, 'e12_error': 0,
                'e12_requester': 3, 'e12_snapshots': 1,
                'e12_selected': 3 if mode == 'enabled' else 0,
                'e12_select_calls': 1 if mode == 'enabled' else 0,
            }
            for key, value in exact.items():
                check(seen.get(key) == value,
                      '%s %s: %s=%r expected %d' %
                      (host, mode, key, seen.get(key), value))
            check(seen.get('spinner', 0) >= 5 and
                  seen.get('predispatch', 0) >= 1,
                  '%s %s: no competing process progress' % (host, mode))
            for key in ('e12_init', 'e12_witness',
                        'e12_waiter', 'e12_holder'):
                check((seen.get(key, 0) & 0o700000) == 0o300000,
                      '%s %s: %s was not live and sleeping' %
                      (host, mode, key))
            kcore = content(archive, mode, 'kcore.map')
            match = re.search(r'(?m)^__kcore_low_end\s+([0-7]+)$', kcore)
            check(match is not None, '%s %s: KCORE end missing' %
                  (host, mode))
            tools = content(archive, mode, 'host-tools-sha256.txt')
            simulator_hash = re.search(r'(?m)^([0-9a-f]{64})\s+\S*/pdp6$',
                                       tools)
            check(simulator_hash is not None,
                  '%s %s: simulator SHA256 missing' % (host, mode))
            result[mode] = (profile, seen, int(match.group(1), 8),
                            simulator_hash.group(1))
    check(result['disabled'][3] == result['enabled'][3],
          host + ': different simulator binary within one host')
    return result


def main():
    check(len(sys.argv) == 3,
          'usage: daimos-oom-cross-platform-v1163.py ANDROID.tgz LINUX.tgz')
    arm = inspect(sys.argv[1], 'android-aarch64')
    linux = inspect(sys.argv[2], 'linux-x86_64')
    check(arm['enabled'][3] != linux['enabled'][3],
          'simulator binaries identical: independence unproven')
    for mode in ('disabled', 'enabled'):
        check(arm[mode][2] == linux[mode][2],
              '%s: different KCORE low endpoints' % mode)
        print('v1163: %s: exact KCORE low end=%06o, physical OOM '
              'requester-only owner and original provider lease PASS' %
              (mode, arm[mode][2]))
    commits = {arm['enabled'][0]['daimos_commit'],
               linux['enabled'][0]['daimos_commit']}
    if len(commits) != 1:
        print('v1163: DAIMOS revisions differ (host-tool-only fix); '
              'this is cross-platform evidence, NOT final E13 signoff')
        for commit in sorted(commits):
            print('v1163: revision ' + commit)
    print('v1163: independent Android/aarch64 and Linux/x86_64 '
          'simulator binaries and enabled/disabled release-media PASS')


if __name__ == '__main__':
    main()
