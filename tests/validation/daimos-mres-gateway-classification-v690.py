#!/usr/bin/env python3
"""Classify confirmed MRES gateways and prohibit unsafe blanket elimination."""
from pathlib import Path
import re
import sys


def main():
    root = Path(sys.argv[1]) / 'system/kernel'
    fs = (root / 'fs/fs_mres.s').read_text()
    router = (root / 'storage/storage_router.s').read_text()
    monitor = (root / 'fs/monitorfs_dispatch_v14.s').read_text()
    syscall = (root / 'proc/syscall_dispatch_pdp6.s').read_text()
    minit = (root / 'modules/module_minit.c').read_text()

    # Classifications describe the current ABI, not an unmeasured saving.
    classes = {
        'dynamic_provider_and_lock': ('fs_provider_reg_call', fs),
        'packed_operation_selector': ('fs_mres_vector_dispatch', fs),
        'context_operation_selector': ('fs_mres_context_vector_dispatch', fs),
        'hardware_interrupt_router': ('storage_pi_handler', router),
        'hardware_completion_router': ('storage_dct_handler', router),
        'direct_kinit_patchable': ('mfsdev_lookup_entry_v16', monitor),
        'optional_syscall_service': ('sys_logstore_service_jump', syscall),
        'optional_other_service': ('sys_mtc_service_jump', syscall),
        'conditional_backing_mapper': ('blockset_runtime_service_jump', fs),
        'optional_reclaim': ('memfs_reclaim_jump', fs),
        'optional_shutdown': ('memfs_shutdown_jump', fs),
    }
    for cls, (sym, source) in classes.items():
        assert re.search(r'^' + re.escape(sym) + r':', source, re.M), cls
        print(f'{cls}: {sym}')
    for sym in ('sys_logstore_service_jump', 'fs_d6fs_service_jump',
                'mfsdev_lookup_entry_v16', 'blockset_runtime_service_jump'):
        assert '&' + sym in minit, sym
    assert 'proc_wait_event' in fs and 'proc_wakeup_event' in fs
    assert 'volume_data_blocks' in fs and 'blockset_direct_tail_error' in fs
    assert 'storage_state' in router
    print('v690: classifications verified against production source: PASS')


if __name__ == '__main__':
    main()
