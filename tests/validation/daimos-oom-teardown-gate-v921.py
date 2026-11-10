#!/usr/bin/env python3
"""v921 fail-closed static OOM teardown audit, not a killer enablement test.

The asserted edges are the real PDP-6 entry points and may not silently
vanish from this safety inventory. This deliberately DOES NOT certify
transitive allocation-freedom, provider liveness or fault rollback.
"""
from pathlib import Path
import os
import re
import sys

repo = Path(os.environ['DAIMOS_REPO'])
sources = {
    'proc': repo / 'system/kernel/proc/proc_pdp6.s',
    'vm': repo / 'system/kernel/proc/vm_pdp6.s',
    'swap': repo / 'system/kernel/proc/vm_pdp6_swap.c',
    'file': repo / 'system/kernel/fs/file_runtime.s',
    'mm': repo / 'system/kernel/mm/mm_pdp6.s',
    'backing': repo / 'system/kernel/storage/backstore.s',
}
text = {k: p.read_text() for k, p in sources.items()}


def asm_body(source, label):
    match = re.search(r'^' + re.escape(label) + r':\s*$',
                      text[source], re.M)
    if match is None:
        raise AssertionError('missing entry: ' + source + ':' + label)
    remaining = text[source][match.end():]
    # Only stop at the next left-margin label. Internal local labels are
    # included; the audit requires an edge before its next entry below.
    stop = re.search(r'^[A-Za-z_][A-Za-z_0-9]*:', remaining, re.M)
    return remaining[:stop.start()] if stop else remaining


def has_call(source, entry, target, window=20000):
    start = re.search(r'^' + re.escape(entry) + r':', text[source], re.M)
    if start is None:
        raise AssertionError('missing entry ' + entry)
    # Scan through the named routine and its local branch labels, but not
    # the next public function. Expected label order is checked below.
    return bool(re.search(r'\bpushj\s+17,' + re.escape(target) + r'\b',
                          text[source][start.end():start.end() + window]))


checks = [
    ('proc', 'proc_event_fatal_other', 'file_close_all_at_v865'),
    ('proc', 'proc_event_fatal_other', 'proc_finish_slot'),
    ('proc', 'proc_finish_slot', 'proc_session_teardown'),
    ('proc', 'proc_finish_slot', 'vm_space_destroy'),
    ('proc', 'proc_finish_slot', 'proc_uarea_release'),
    ('proc', 'proc_uarea_release', 'mm_free'),
    ('vm', 'vm_space_destroy', 'fs_provider_reg_call'),
    ('vm', 'vm_space_destroy', 'mm_free'),
    ('vm', 'vm_space_destroy', 'proc_swap_detach'),
    ('file', 'file_close_all_at_v865', 'file_close_entry_v865'),
    ('file', 'file_close_entry_v865', 'vfs_sync'),
    ('mm', 'mm_free', 'mm_delete'),
]
for src, entry, target in checks:
    assert has_call(src, entry, target), 'missing audit edge: %s -> %s' % (
        entry, target)
    print('EDGE %-29s -> %s' % (entry, target))

# Ensure that no automatic OOM kill was slipped into MM pressure code.
# These are currently selector-only entry points, not a teardown engine.
assert not re.search(r'\bpushj\s+17,proc_oom_select_v863\b',
                     text['mm']), 'MM pressure gained an OOM selector call'
assert 'proc_oom_select_v863:' not in text['proc']

# Every nonzero scheduler wait class denotes a live private executive
# continuation, including WAIT_CHILD (which lacks WAIT_EVENT's low bit).
for symbol, value in (('PROC_WAIT_EVENT_LH', '020000'),
                      ('PROC_WAIT_CHILD_LH', '040000'),
                      ('PROC_WAIT_INTR_LH', '060000'),
                      ('PROC_WAIT_LH_MASK', '060000')):
    assert re.search(r'^\s*\.equ\s+' + symbol + r',\s*' + value +
                     r'\s*$', text['proc'], re.M), 'wait encoding changed: '+symbol
for entry in ('proc_finish_new_v881', 'proc_event_fatal_other',
              ):
    part = asm_body('proc', entry)
    assert 'tlne    1,PROC_WAIT_LH_MASK' in part, (
        'incomplete private-stack wait guard: ' + entry)
    # Wakeup clears the wait marker before a resumed executive stack has
    # returned to user mode. Saved CTX_PC is the second ownership test.
    assert 'CTX_PC(' in part and '010000' in part, (
        'missing saved executive-continuation guard: ' + entry)

assert 'backstore_free(first, blocks) != 0' in text['swap']
assert 'proc_storage_publish_v30' in text['swap']
assert 'proc_swap_detach(int slot)' in text['swap']

print('v921: faulting-process policy / direct finalizer / fatal gateway inventory PASS')
print('v921: release chain NOT CERTIFIED for OOM termination:')
print('  FILE close may call VFS_SYNC and sleep in the serialized provider')
print('  session teardown can send HUP and fail after partial delivery')
print('  VM destruction invokes provider, MM free, and swap backing detach')
print('  MM extent deletion is in-place, but cannot prove downstream liveness')
print('  provider timeout, rollback and allocation-free completion remain P0')
print('v921: automatic OOM termination must remain disabled')
