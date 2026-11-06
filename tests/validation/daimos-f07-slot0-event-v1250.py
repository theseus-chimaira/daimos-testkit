#!/usr/bin/env python3
"""Add device and stack ownership evidence to the v1249 PI snapshot.

The simulator reads the exact addresses from the guest's link map.  The
physical stack inspection is deliberately broad because KINIT allocates
the idle stack dynamically and its base is not known until boot.
"""

from pathlib import Path
import runpy
import sys


NAMES = (
    'drm236_active_request', 'drm236_pending_request',
    'storage_state', 'storage_count',
    'fs_provider_ready', 'fs_provider_wait_event_v917',
    'mach_kernel_stack_base', 'pdp10_pi_level6',
)


def produce(boot, kernel_map):
    path = Path(__file__).with_name('daimos-f07-pi-map-probe-v1249.py')
    api = runpy.run_path(str(path))
    base = api['read_symbols'](kernel_map)
    script = api['generate'](boot, base)
    mapping = {}
    for line in kernel_map.splitlines():
        fields = line.split()
        if len(fields) < 2 or fields[0] not in NAMES:
            continue
        name = fields[0]
        if name in mapping:
            raise ValueError('duplicate device symbol: ' + name)
        try:
            address = int(fields[1], 8)
        except ValueError as exc:
            raise ValueError('invalid device address: ' + name) from exc
        if address < 0 or address > 0o777777:
            raise ValueError('device address out of range: ' + name)
        mapping[name] = address
    missing = set(NAMES).difference(mapping)
    if missing:
        raise ValueError('missing device symbols: ' + ','.join(sorted(missing)))
    probe = ''.join('; v1250 %s\nexamine %06o\n' %
                    (name, mapping[name]) for name in NAMES)
    # Stack frames and the live AC words are necessary to identify the
    # source of an uncompleted proc_wait_boot event pointer.
    probe += '; v1250 fast ACs\nexamine 0-17\n'
    probe += '; v1250 idle/early-uarea core\nexamine 046000-050000\n'
    return script.replace('go 020\n', 'go 020\n' + probe, 1)


def main():
    if len(sys.argv) != 4:
        raise SystemExit('usage: v1250 BOOT.INI KCORE.MAP OUTPUT.INI')
    output = Path(sys.argv[3])
    if output.exists():
        raise SystemExit('v1250: output already exists')
    script = produce(Path(sys.argv[1]).read_text(),
                     Path(sys.argv[2]).read_text())
    output.write_text(script)
    print('v1250: resolved device and scheduler addresses from guest map')


if __name__ == '__main__':
    main()
