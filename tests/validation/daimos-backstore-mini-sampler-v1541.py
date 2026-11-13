#!/usr/bin/env python3
"""Use the accepted v1306 SIMH monitor with only v1541 physical witnesses.

The old v1511 diagnostic requests hundreds of MM words per interrupt.
Its single oversized PTY write can block when the console input queue is
full. V1541 only needs the real slot-0 owner, Type-236 error and swap
ownership witnesses; limit the queried addresses rather than changing
the production simulator or fabricating physical results.
"""

import importlib.util
from pathlib import Path
import sys


NAMES = (
    'f07s_diag_timer_clock',
    'f07s_diag_sched_cursor',
    'f07s_final_backstore_used',
    'v1494_faults',
    'v1494_slot',
    'v1511_device_errors',
    'v1511_drm_errors',
)


def main():
    # v1511's detailed sampler additionally accepts --kcore-map for its
    # large postflight table. The v1306 monitor only needs the linked
    # physical-address list; the v1541 oracle checks the map separately.
    if '--kcore-map' in sys.argv:
        index = sys.argv.index('--kcore-map')
        if index + 1 >= len(sys.argv):
            raise SystemExit('missing --kcore-map argument')
        del sys.argv[index:index + 2]
    original = Path(__file__).with_name(
        'daimos-simh-swap-live-sampler-v1306.py')
    spec = importlib.util.spec_from_file_location(
        'daimos_v1541_physical_sampler', str(original))
    assert spec is not None and spec.loader is not None
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    module.FIELDS = NAMES

    def concise_summary(sample, pc, data):
        return ('v1541 sample=%d PC=%06o ticks=%d cursor=%06o '
                'faults=%d slot=%d pi2_device_errors=%d '
                'drm_errors=%d backstore_used=%d' %
                (sample, pc, data['f07s_diag_timer_clock'],
                 data['f07s_diag_sched_cursor'], data['v1494_faults'],
                 data['v1494_slot'], data['v1511_device_errors'],
                 data['v1511_drm_errors'],
                 data['f07s_final_backstore_used']))

    module.summary = concise_summary
    return module.main()


if __name__ == '__main__':
    sys.exit(main())
