#!/usr/bin/env python3
"""Generate a versioned PDP-6 PI diagnostic from the exact guest map.

No production source changes. All scheduler locations are resolved from
the matching KCORE link map; stale numeric addresses are never accepted.
"""

from pathlib import Path
import sys


SYMBOLS = (
    'proc_sched_cursor', 'proc_current_slot', 'proc_runq_head',
    'proc_timer_clock', 'proc_timer_next', 'proc_sched_kick',
    'proc_swap_pressure_ticks',
    'proc_swap_blocks_used', 'proc_high_slot', 'proc_table',
    'mach_kernel_sp',
)

REGISTERS = (
    'PIH', 'PIE', 'PIR', 'PIENB', 'PIHOLD', 'PIREST',
    'PIEN', 'CLK', 'CLKEN',
)


def read_symbols(source):
    result = {}
    required = set(SYMBOLS)
    for line in source.splitlines():
        fields = line.split()
        if len(fields) < 2 or fields[0] not in required:
            continue
        name = fields[0]
        if name in result:
            raise ValueError('duplicate map symbol: ' + name)
        try:
            value = int(fields[1], 8)
        except ValueError as error:
            raise ValueError('invalid map address: ' + name) from error
        if value < 0 or value > 0o777777:
            raise ValueError('map address out of range: ' + name)
        result[name] = value
    missing = required.difference(result)
    if missing:
        raise ValueError('missing KCORE map symbols: ' + ','.join(sorted(missing)))
    return result


def generate(boot_source, mapping):
    anchor = 'go 020\n'
    if boot_source.count(anchor) != 1:
        raise ValueError('expected exactly one guest go 020 command')
    lines = ['go 020']
    lines.extend('examine ' + reg for reg in REGISTERS)
    # Comments preserve names in the resulting simulator transcript.
    # SIMH's numeric examine command is kept separate from the comment.
    for name in SYMBOLS:
        lines.append('; v1249 ' + name)
        lines.append('examine %06o' % mapping[name])
    return boot_source.replace(anchor, '\n'.join(lines) + '\n', 1)


def main():
    if len(sys.argv) != 4:
        raise SystemExit('usage: v1249 BOOT.INI KCORE.MAP OUTPUT.INI')
    boot = Path(sys.argv[1]).read_text()
    mapping = read_symbols(Path(sys.argv[2]).read_text())
    output = Path(sys.argv[3])
    if output.exists():
        raise SystemExit('v1249: output exists: ' + str(output))
    output.write_text(generate(boot, mapping))
    print('v1249: resolved %d KCORE symbols from matching link map' %
          len(SYMBOLS))


if __name__ == '__main__':
    main()
