#!/usr/bin/env python3
"""v963: live lookup/attach and VFS PURE lifetime source contract.

Non-mutating source audit; the sibling v961/v962 native tests execute the
production guards and a separate 256K guest checks boot integration.
"""
from pathlib import Path
import sys
root = Path(sys.argv[1]) / 'system/kernel'
exec_load = (root/'proc/exec_load.s').read_text()
attach = (root/'proc/proc_pure_attach.c').read_text()
vfs = (root/'fs/vfs.s').read_text()
guards = (root/'proc/proc_pure_backing_pdp6.s').read_text()

def ordered(source, *items):
    cursor = -1
    for item in items:
        cursor = source.find(item, cursor + 1)
        assert cursor >= 0, 'missing or unordered: ' + item

def within(source, begin, end):
    assert source.count(begin) == 1
    return source.split(begin, 1)[1].split(end, 1)[0]

load = within(exec_load, '\nexec_load_process:', '\nexec_load_vm_fail:')
ordered(load, 'pushj   17,file_lookup_path', 'pushj   17,vfs_stat',
        'pushj   17,file_check_access', 'pushj   17,vfs_read_words',
        'pushj   17,vm_space_load_file', 'exec_load_attach:',
        'pushj   17,proc_swap_attach')
ordered(attach, 'provider = VFS_PROVIDER(backing);',
        'mount = VFS_MOUNT_ID(backing);',
        'kind = VFS_LOCAL_KIND(backing);',
        'VFS_PROVIDER(vfs_mount_root_base[mount - 1U]) != provider',
        'VFS_MOUNT_ID(vfs_mount_root_base[mount - 1U]) != mount',
        'proc_swap_records[slot].state = packed;')
lookup = within(vfs, '\nvfs_lookup:', '\n; int vfs_readdir(')
ordered(lookup, 'vfs_lookup_provider:', 'pushj   17,fs_provider_reg_call',
        'vfs_lookup_return:', 'pushj   17,vfs_lookup_resolve_mount')
unmount = within(vfs, '\nvfs_unmount:', '\nvfs_mount_retire_slot:')
ordered(unmount, 'pushj   17,proc_swap_mount_busy',
        'jumpn   1,vfs_unmount_fail', 'pushj   17,vfs_sync')
write = within(vfs, '\nvfs_write_guard_v449:', '\nvfs_write_words_ro:')
ordered(write, 'pushj   17,proc_swap_backing_busy',
        'jumpn   1,vfs_write_words_ro', 'jrst    fs_provider_reg_call')
for routine, label in [('proc_swap_mount_busy:', 'proc_swap_mount_record_v961:'),
                       ('proc_swap_backing_busy:', 'proc_swap_backing_record_v962:')]:
    body = guards.split(routine, 1)[1]
    assert label in body
    assert 'proc_swap_records' in body.split(label, 1)[0]
    assert 'PROC_SWAP_BACKING_OFFSET(1)' in body.split(label, 1)[0]
print('v963: VFS lookup, live root attach, mount and write lifetime contract PASS')
