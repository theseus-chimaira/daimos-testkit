#!/usr/bin/env python3
"""Read an F07 stop and prepare SIMH follow-up on the saved exact machine.

No process or hardware state is modified. The script never resumes the guest;
it only writes a RESTORE/EXAMINE/EXIT command file for read-only inspection.
"""

from pathlib import Path
import re
import sys


MASK = 0o777777
STATES = ('FREE', 'OTHER', 'RUN', 'SLEEP', 'ZOMBIE', 'OTHER5',
          'STOP', 'OTHER7')


def observations(addresses, text):
    values = {}
    for line in addresses.splitlines():
        parts = line.split()
        if len(parts) != 2:
            continue
        name, raw = parts
        if not (name.startswith('f07q_slot') or
                name in ('fs_provider_ready', 'fs_provider_wait_event_v917',
                         'drm236_active_request', 'drm236_pending_request',
                         'storage_state', 'proc_timer_clock',
                         'proc_current_slot', 'proc_sched_cursor',
                         'proc_runq_head', 'proc_high_slot', 'proc_table')):
            continue
        address = int(raw, 8)
        matches = re.findall(r'(?m)^\s*0*%o:\s*([0-7]+)' % address, text)
        if not matches:
            raise ValueError('missing simulator observation: ' + name)
        if name in values:
            raise ValueError('duplicate address name: ' + name)
        values[name] = int(matches[0], 8)
    return values


def provider_owner(value):
    if value & MASK:
        return 'FREE'
    owner = value >> 18
    if owner == 0:
        return 'INVALID (no owner and no free bit)'
    return 'PID %d' % (owner - 1)


def saved_process(values, slot):
    prefix = 'f07q_slot'
    try:
        meta = values[prefix + '%03o' % (slot * 3)]
        vm = values[prefix + '%03o' % (slot * 3 + 1)]
        sched = values[prefix + '%03o' % (slot * 3 + 2)]
    except KeyError:
        return None
    return meta, vm, sched


def render(values, savefile):
    print('F07 v1254: diagnostic-only frozen provider and DMA ownership')
    print('filesystem lease:', provider_owner(values['fs_provider_ready']))
    print('lease word:       %012o' % values['fs_provider_ready'])
    print('lease event:      %012o' % values['fs_provider_wait_event_v917'])
    for name in ('drm236_active_request', 'drm236_pending_request',
                 'storage_state', 'proc_timer_clock', 'proc_current_slot',
                 'proc_sched_cursor', 'proc_runq_head'):
        print('%-19s %012o' % (name, values[name]))
    followup = ['restore %s\n' % savefile]
    used = set()

    def sample(address):
        if address in used or address <= 0 or address > MASK:
            return
        used.add(address)
        followup.append('examine %o\n' % address)

    for name in ('drm236_active_request', 'drm236_pending_request'):
        pointer = values[name] & MASK
        if pointer:
            for at in (pointer, pointer + 1, pointer + 2):
                sample(at)
    # v1255: the optional v1238 full-descriptor dump may not be enabled
    # in a v1254 guest. The stopped kernel still exposes the *actual*
    # descriptor array base and high-water slot; inspect it directly.
    # Include every occupied/empty descriptor so later decoding does not
    # need to guess process state or reconstruct a live MM allocation.
    table = values.get('proc_table', 0) & MASK
    high_slot = values.get('proc_high_slot', 0) & MASK
    if table and 1 < high_slot <= 0o100 and table + 3 * high_slot <= MASK:
        for slot in range(1, high_slot):
            for offset in range(3):
                sample(table + 3 * slot + offset)
    else:
        print('process descriptor source: INVALID/MISSING table or bound')
    print('PID  state    wait_event   vm_base')
    for slot in (1, 2, 3, 4, 5, 6, 7, 13, 24):
        desc = saved_process(values, slot)
        if desc is None:
            continue
        _, vm, sched = desc
        state = STATES[(sched >> 33) & 7]
        wait = sched & MASK
        print('%3d  %-7s  %06o       %06o' % (slot, state,
                                              wait, vm & MASK))
        if state == 'SLEEP' and wait and not (wait & 0o400000):
            for at in (wait - 2, wait - 1, wait, wait + 1):
                sample(at)
    # The provider event is global; inspect its containing words too.
    followup.append('exit\n')
    return ''.join(followup)


def main():
    if len(sys.argv) != 4:
        raise SystemExit('usage: v1254 ADDRESSES SIMH_LOG SNAPSHOT_DIRECTORY')
    directory = Path(sys.argv[3])
    checkpoint = directory / 'guest-v1254.sav'
    if not checkpoint.is_file():
        raise SystemExit('v1254: no saved machine state')
    address_text = Path(sys.argv[1]).read_text()
    address_text += '\n' + (directory / 'addresses-v1254.txt').read_text()
    simh_text = Path(sys.argv[2]).read_text(errors='replace')
    if '?RT' in simh_text or '<+' not in simh_text:
        raise SystemExit('v1254: unusable root media or no RUN progress')
    values = observations(address_text, simh_text)
    output = directory / 'inspect-v1254.ini'
    if output.exists():
        raise SystemExit('v1254: refusing to overwrite inspection command file')
    output.write_text(render(values, checkpoint))
    print('read-only SIMH inspection commands:', output)


if __name__ == '__main__':
    main()
