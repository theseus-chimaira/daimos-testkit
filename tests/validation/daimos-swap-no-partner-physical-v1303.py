#!/usr/bin/env python3
"""Classify physical F07 no-exchange-partner evidence without guessing.

The v1209 counters execute in an isolated kernel only.  The optional
v1219 allocator probe captures the actual failed MM allocation.
An ordinary swapping PASS is not proof that the no-partner path ran.
"""

from pathlib import Path
import re
import sys


FIELDS = ('pressure', 'fallback', 'victim_search', 'reclaim_ok',
          'reclaim_fail', 'swapout_ok', 'swapout_fail', 'swapin_ok',
          'swapin_pressure', 'swapin_fail', 'cooldown', 'exchanged',
          'restored')
ALLOC = ('calls', 'error', 'owner', 'requested', 'extents',
         'low_fit', 'low_base_or_free', 'high_fit',
         'high_base_or_free', 'meta')
LIVE_KEYS = ({'f07s_diag_' + name for name in FIELDS} |
             {'f07a_' + name for name in ALLOC} |
             {'f07s_final_swap_blocks', 'f07s_final_backstore_used'})


def decode(address_file, simh_file, snapshot=False):
    text = Path(simh_file).read_text(errors='replace')
    if '[v1306]' in text and not snapshot:
        # Completed PTY-sampled guests have multiple read-only samples.
        # Their authoritative after-HALT accounting follows the last
        # HALT message.  Never interpret an intermediate counter sample
        # as the final resource-cleanup result.
        marker = text.rfind('HALT instruction, PC:')
        if marker < 0:
            raise ValueError('live-sampled guest lacks HALT postflight')
        text = text[marker:]
    names = {}
    for line in Path(address_file).read_text().splitlines():
        parts = line.split()
        if len(parts) != 2:
            raise ValueError('invalid address row')
        key, addr = parts
        # Read only this verifier's established schema. Newer read-only
        # samplers publish additional f07s_diag_* addresses (for example
        # the v1342 timer frontier), but those words are not necessarily
        # present in the after-HALT postflight script. Requiring every
        # future diagnostic as a final resource counter would reject a
        # genuinely completed guest without checking its real invariants.
        if key not in LIVE_KEYS:
            continue
        if key in names:
            raise ValueError('duplicate label ' + key)
        # SIMH's interactive PTY console prefixes every response with
        # "sim> "; normal post-HALT script output omits that prefix.
        pattern = (r'(?m)^(?:sim>\s*)?0*%o\s*:\s*([0-7]+)' %
                   int(addr, 8))
        found = re.findall(pattern, text)
        if snapshot and key.startswith('f07s_final_') and not found:
            # Live Ctrl-E sampling reads the two backing counters,
            # not every end-of-guest F07 postflight diagnostic word.
            continue
        if not found or (len(found) != 1 and not snapshot):
            raise ValueError('missing/duplicate physical sample ' + key)
        names[key] = int(found[-1], 8)
    counts = {key: names['f07s_diag_' + key] for key in FIELDS}
    alloc = {key: names['f07a_' + key] for key in ALLOC}
    return counts, alloc, names


def check_counts(data):
    if data['fallback'] != 0:
        raise ValueError('production source unexpectedly uses v1208 fallback')
    if data['pressure'] != data['exchanged'] + data['cooldown']:
        raise ValueError('pressure is not fully accounted for')
    if data['swapin_pressure'] != data['pressure']:
        raise ValueError('swap-in allocator result inconsistent')
    if data['swapin_fail']:
        raise ValueError('unresolved fatal swap-in transaction')
    # The source-linked v1209 swapout_fail probe is at the shared
    # proc_swap_out_fail label. That label is also reached when a
    # candidate is simply ineligible (pinned VM, nonresident state,
    # owner-side teardown, etc.), before any backing transaction.
    # Therefore this counter is NOT a fatal-I/O counter. Treat it as
    # a diagnostic; final swap/backstore zero-leak accounting, exact
    # restore balance and original guest HALT remain mandatory.
    if data['swapin_ok'] != data['restored']:
        raise ValueError('ordinary restores are unbalanced')


def verify(counts, alloc, names):
    check_counts(counts)
    if counts['swapin_ok'] + counts['exchanged'] == 0:
        raise ValueError('no successful swap or exchange progress')
    if counts['pressure'] != alloc['calls']:
        raise ValueError('MM failed-allocation instrumentation mismatch')
    # Simulated full-system pressure must be the real allocator result,
    # never an injected fake counter or a guessed return status.
    if counts['pressure']:
        err = alloc['error']
        if err & (1 << 35):
            err -= 1 << 36
        if err not in (-1, -2, -3):
            raise ValueError('MM failure is not a typed resource error')
    if counts['cooldown'] == 0:
        return False
    if alloc['calls'] == 0 or counts['swapin_pressure'] == 0:
        raise ValueError('no-partner cooldown without physical MM pressure')
    if counts['exchanged'] + counts['cooldown'] != counts['pressure']:
        raise ValueError('no-partner accounting inconsistent')
    for required in ('f07s_final_swap_blocks',
                     'f07s_final_backstore_used'):
        if required not in names or names[required] != 0:
            raise ValueError('backing blocks were not released: ' + required)
    return True


def main():
    if sys.argv[1:] == ['--self-test']:
        counts = dict.fromkeys(FIELDS, 0)
        counts['swapin_ok'] = 41
        counts['restored'] = 41
        alloc = dict.fromkeys(ALLOC, 0)
        names = {'f07s_final_swap_blocks': 0,
                 'f07s_final_backstore_used': 0}
        if verify(counts, alloc, names):
            raise AssertionError('ordinary swaps misclassified as no-partner')
        alloc['calls'] = 2
        alloc['error'] = (1 << 36) - 1
        counts['pressure'] = 2
        counts['swapin_pressure'] = 2
        counts['cooldown'] = 2
        if not verify(counts, alloc, names):
            raise AssertionError('real no-partner evidence rejected')
        mutations = (
            ('unknown-pressure', ('pressure', 3)),
            ('fake-fallback', ('fallback', 1)),
            ('fatal-failure', ('swapin_fail', 1)),
            ('unbalanced-restore', ('restored', 40)),
            ('fake-mm-count', ('cooldown', 1)),
        )
        for label, (key, value) in mutations:
            mutant = dict(counts)
            mutant[key] = value
            try:
                verify(mutant, alloc, names)
            except ValueError:
                continue
            raise AssertionError('unsafe mutation accepted: ' + label)
        print('v1303: ordinary-swapping negative, positive no-partner '
              'classification and five unsafe mutations PASS')
        return 0
    if sys.argv[1:2] == ['--snapshot']:
        if len(sys.argv) != 4:
            raise SystemExit('usage: v1303 --snapshot ADDRESSES SIMH-OUTPUT')
        counts, alloc, names = decode(sys.argv[2], sys.argv[3], snapshot=True)
        check_counts(counts)
        if alloc['calls'] != counts['pressure']:
            raise ValueError('snapshot allocator-pressure counter mismatch')
        print('v1303: partial snapshot: out=%d in=%d pressure=%d '
              'exchange=%d cooldown=%d MM-errors=%d' %
              (counts['swapout_ok'], counts['swapin_ok'],
               counts['pressure'], counts['exchanged'],
               counts['cooldown'], alloc['calls']))
        print('v1303: snapshot is NOT full-guest liveness acceptance')
        return 3
    if len(sys.argv) != 3:
        raise SystemExit('usage: v1303 ADDRESSES SIMH-OUTPUT '
                         'or --self-test')
    guest_text = Path(sys.argv[2]).read_text(errors='replace')
    if 'HALT' not in guest_text or 'KWP' not in guest_text:
        raise ValueError('no completed requester/witness guest evidence')
    counts, alloc, names = decode(sys.argv[1], sys.argv[2])
    passed = verify(counts, alloc, names)
    for label, transform in (
        ('unaccounted-pressure', ('pressure', counts['pressure'] + 1)),
        ('unexpected-fallback', ('fallback', 1)),
        ('fatal-swap', ('swapin_fail', 1)),
        ('mismatched-restore', ('restored', counts['restored'] + 1)),
    ):
        mutant = dict(counts)
        mutant[transform[0]] = transform[1]
        try:
            verify(mutant, alloc, names)
        except ValueError:
            continue
        raise AssertionError('mutant escaped: ' + label)
    print('v1303: MM fail=%d swapin=%d exchange=%d cooldown=%d' %
          (alloc['calls'], counts['swapin_ok'], counts['exchanged'],
           counts['cooldown']))
    if not passed:
        print('v1303: full guest PASS but real no-partner condition '
              'NOT EXERCISED; liveness remains open')
        return 3
    print('v1303: real no-partner cooldown exercised; guest completed '
          'with ordinary restores and zero leaked backing PASS')
    return 0


if __name__ == '__main__':
    sys.exit(main())
