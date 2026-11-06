#!/usr/bin/env python3
"""Decode exact slot-0 event and DRM descriptor provenance after SIMH stop."""

from pathlib import Path
import re
import sys


FIELDS = (
    'calls', 'event', 'event_value', 'sp', 'caller',
    'drm_active', 'drm_pending', 'storage_state', 'storage_iowd',
    'sched_cursor', 'current_slot', 'timer_clock', 'swap_backoff',
    'pi_state', 'saved_ac0',
)
RH = 0o777777


def read_observation(address_text, simh_text):
    addresses = {}
    for line in address_text.splitlines():
        words = line.split()
        if len(words) != 2 or not words[0].startswith('f07wait_'):
            continue
        key = words[0][8:]
        if key in addresses:
            raise ValueError('duplicate slot-0 observation: ' + key)
        addresses[key] = int(words[1], 8)
    if set(addresses) != set(FIELDS):
        raise ValueError('incomplete slot-0 wait address set')
    values = {}
    for name, address in addresses.items():
        pattern = r'(?m)^\s*0*%o\s*:\s*([0-7]+)' % address
        matches = re.findall(pattern, simh_text)
        if len(matches) != 1:
            raise ValueError('missing/repeated SIMH value: ' + name)
        values[name] = int(matches[0], 8)
    return values


def classify(values):
    event = values['event']
    descriptor = event - 2
    active = values['drm_active'] & RH
    pending = values['drm_pending'] & RH
    if descriptor == active and active != 0:
        return 'slot-0 event belongs to active DRM descriptor'
    if descriptor == pending and pending != 0:
        return 'slot-0 event belongs to pending DRM descriptor'
    if active and descriptor != active:
        return 'slot-0 event differs from active DRM descriptor'
    if pending and descriptor != pending:
        return 'slot-0 event differs from pending DRM descriptor'
    return 'no matching DRM descriptor; inspect other event users'


def closest_symbol(map_text, address):
    matches = []
    for line in map_text.splitlines():
        fields = line.split()
        if len(fields) < 2:
            continue
        try:
            current = int(fields[1], 8)
        except ValueError:
            continue
        if current <= address:
            matches.append((current, fields[0]))
    if not matches:
        return 'no preceding symbol'
    offset, name = max(matches)
    return '%s+%o' % (name, address - offset)


def main():
    if len(sys.argv) != 4:
        raise SystemExit('usage: v1250 ADDRESSES SIMH.OUT KCORE.MAP')
    values = read_observation(Path(sys.argv[1]).read_text(),
                              Path(sys.argv[2]).read_text(errors='replace'))
    mapping = Path(sys.argv[3]).read_text()
    print('slot-0 wait calls: %d' % values['calls'])
    for name in FIELDS:
        print('%-17s %012o' % (name, values[name]))
    print('DRM ownership:', classify(values))
    print('PUSHJ caller:', closest_symbol(mapping, values['caller'] & RH))


if __name__ == '__main__':
    main()
