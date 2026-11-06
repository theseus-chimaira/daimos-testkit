#!/usr/bin/env python3
"""Deterministic report checks; no PDP-6 boot or writable media needed."""

import importlib.util
from pathlib import Path
from contextlib import redirect_stdout
from io import StringIO


module_path = Path(__file__).with_name('daimos-f07-provider-report-v1254.py')
spec = importlib.util.spec_from_file_location('f07v1254', module_path)
mod = importlib.util.module_from_spec(spec)
spec.loader.exec_module(mod)

assert mod.provider_owner(1) == 'FREE'
assert mod.provider_owner(0) == 'INVALID (no owner and no free bit)'
assert mod.provider_owner(7 << 18) == 'PID 6'

values = dict.fromkeys(('fs_provider_ready', 'fs_provider_wait_event_v917',
                        'drm236_active_request', 'drm236_pending_request',
                        'storage_state', 'proc_timer_clock',
                        'proc_current_slot', 'proc_sched_cursor',
                        'proc_runq_head'), 0)
values['fs_provider_ready'] = 5 << 18
values['drm236_active_request'] = (0o454 << 18) | 0o52146
values['drm236_pending_request'] = 0o52745
values['f07q_slot011'] = 0
values['f07q_slot012'] = 0o44000 << 18
values['f07q_slot013'] = (0o340000 << 18) | 0o52150
values['f07q_slot014'] = 0
values['f07q_slot015'] = 0o44000 << 18
values['f07q_slot016'] = (0o340000 << 18) | 0o52747
values['f07q_slot022'] = 0
values['f07q_slot023'] = 0
values['f07q_slot024'] = (0o340000 << 18) | 0o23130
log = StringIO()
with redirect_stdout(log):
    script = mod.render(values, Path('/var/guest-v1254.sav'))
assert 'filesystem lease: PID 4' in log.getvalue()
assert 'restore /var/guest-v1254.sav\n' in script
for address in (0o52146, 0o52147, 0o52150, 0o52745, 0o52747,
                0o23130):
    assert script.count('examine %o\n' % address) == 1
assert script.endswith('exit\n')
print('v1254: provider owner, process waits, DMA pointers and event dedup PASS')
