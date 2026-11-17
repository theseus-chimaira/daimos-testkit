#!/usr/bin/env python3
"""Fail-closed linked KINIT/KCORE/MRES startup-execution provenance profile.

Count real AAP instruction-starts and executed opcodes from ET0A, never the
stale opcode value associated with an IT0 fetch. Exception/PI events block
ordinary logical-tick cost attribution; this is a dynamic opcode-frequency
profile until a class-clean timing segment has been independently isolated.
"""
import argparse
from collections import Counter, defaultdict
import json
from pathlib import Path
import re

SYMBOL = re.compile(r'^([A-Za-z_.$%][\w.$%]*)\s+([0-7]{6})$')
START = re.compile(r'^AAP_TIMING_V1 IT0 tick=(\d+) pc=([0-7]{6}) inst=([0-7]{3})$')
EXEC = re.compile(r'^AAP_TIMING_V1 ET0A tick=(\d+) pc=([0-7]{6}) inst=([0-7]{3})$')
CLASS = re.compile(r'^AAP_CLASS_EVENT_V1 type=(NXM|ILLOP|PDLOV|PI_CYCLE) tick=(\d+) pc=([0-7]{6})$')
REQUIRED = ('kinit_enter', 'kcore_load', 'mres_init', 'mres_install',
            'module_run_minits', '__kcore_low_end', '__kcore_load_begin')
KCORE_SAMPLES = (0o22674, 0o22675)
MRES_SAMPLES = (0o23771, 0o24000)


def read_symbols(path):
    symbols = {}
    for line in Path(path).read_text().splitlines():
        match = SYMBOL.fullmatch(line)
        if match:
            symbols[match.group(1)] = int(match.group(2), 8)
    missing = set(REQUIRED) - set(symbols)
    if missing:
        raise ValueError('linked symbol map missing: ' + ', '.join(sorted(missing)))
    return symbols


def validate_image(image, symbols, readbacks):
    lines = Path(image).read_text().splitlines()
    entry = symbols['kinit_enter']
    if len(lines) < 3 or int(lines[1], 8) & 0o777777 != entry-0o30000:
        raise ValueError('linked KINIT entry does not match image header')
    for addr in (entry, *KCORE_SAMPLES):
        source = addr if addr == entry else symbols['__kcore_load_begin'] + addr-0o60
        idx = 2+source-0o30000
        if not (0 <= idx < len(lines)):
            raise ValueError('linked image word outside image at %06o' % addr)
        if addr not in readbacks or readbacks[addr] != int(lines[idx], 8):
            raise ValueError('linked instruction provenance mismatch at %06o' % addr)
    for addr in MRES_SAMPLES:
        if addr not in readbacks or readbacks[addr] == 0:
            raise ValueError('MRES installed code absent at %06o' % addr)
    return entry


def profile(trace, image, symbol_map, readbacks):
    symbols = read_symbols(symbol_map)
    entry = validate_image(image, symbols, readbacks)
    end = symbols['__kcore_low_end']
    if not (0o1000 < min(KCORE_SAMPLES) < end <= min(MRES_SAMPLES) < 0o30000):
        raise ValueError('unsupported or inconsistent KCORE/MRES boundaries')
    regions = Counter()
    opcodes = defaultdict(Counter)
    addresses = defaultdict(Counter)
    exceptional = Counter()
    entry_seen = False
    pending_pc = None
    pending_timed_opcode = False
    executed_ops = defaultdict(set)
    ticks_at = {}
    total = 0
    for line in Path(trace).open():
        line = line.rstrip('\n')
        event = CLASS.fullmatch(line)
        if event:
            if entry_seen:
                exceptional[event.group(1)] += 1
            pending_pc = None
            continue
        start = START.fullmatch(line)
        if start:
            pc = int(start.group(2), 8)
            if not entry_seen and pc == entry:
                entry_seen = True
            pending_pc = pc if entry_seen else None
            pending_timed_opcode = False
            if entry_seen:
                total += 1
                ticks_at.setdefault(pc, int(start.group(1)))
                if 0o1000 <= pc < end:
                    region = 'kcore'
                elif end <= pc < 0o30000:
                    region = 'mres'
                else:
                    region = 'kinit_or_other'
                regions[region] += 1
                addresses[region][pc] += 1
            continue
        exe = EXEC.fullmatch(line)
        if exe and pending_pc == int(exe.group(2), 8) and not pending_timed_opcode:
            pc = pending_pc
            opcode = int(exe.group(3), 8)
            executed_ops[pc].add(opcode)
            if 0o1000 <= pc < end:
                opcodes['kcore'][opcode] += 1
            elif end <= pc < 0o30000:
                opcodes['mres'][opcode] += 1
            pending_timed_opcode = True
        elif line.startswith('AAP_TIMING_V1 ') and not (start or exe):
            raise ValueError('unknown AAP timing milestone')
        elif line.startswith('AAP_CLASS_EVENT_V1 ') and not event:
            raise ValueError('unknown exceptional event')
    if not entry_seen:
        raise ValueError('no genuine KINIT instruction-start at linked entry')
    if not all(addresses['kcore'][pc] for pc in KCORE_SAMPLES):
        raise ValueError('real KCORE instruction-start samples missing')
    if not all(addresses['mres'][pc] for pc in MRES_SAMPLES):
        raise ValueError('real installed MRES instruction-start samples missing')
    for label in ('mres_init', 'mres_install', 'module_run_minits'):
        if symbols[label] not in ticks_at:
            raise ValueError('no execution of ' + label)
    for pc in (*KCORE_SAMPLES, *MRES_SAMPLES, entry):
        if readbacks[pc] >> 27 & 0o777 not in executed_ops[pc]:
            raise ValueError('linked word opcode mismatched at %06o' % pc)
    return {
        'schema':'aap-linked-runtime-profile-v2',
        'entry': '%06o' % entry,
        'resident_kcore_end': '%06o' % end,
        'instruction_starts_after_entry': total,
        'region_starts': dict(regions),
        'region_distinct_pcs': {name:len(counts) for name,counts in addresses.items()},
        'real_kcore_pcs': {'%06o'%pc:addresses['kcore'][pc] for pc in KCORE_SAMPLES},
        'real_mres_pcs': {'%06o'%pc:addresses['mres'][pc] for pc in MRES_SAMPLES},
        'kcore_opcode_starts': {'%03o'%op:n for op,n in opcodes['kcore'].most_common()},
        'mres_opcode_starts': {'%03o'%op:n for op,n in opcodes['mres'].most_common()},
        'exception_events': dict(exceptional),
        'ordinary_tick_cost_valid': not bool(exceptional),
        'scope':'linked kernel/module startup only; complete boot and representative sustained hotpaths not proven',
    }


def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('trace')
    p.add_argument('image')
    p.add_argument('symbols')
    p.add_argument('snapshot', help='JSON address-to-word dictionary, keys and values octal')
    p.add_argument('--json', dest='output')
    a = p.parse_args()
    snapshot={int(k,8):int(v,8) for k,v in json.loads(Path(a.snapshot).read_text()).items()}
    report=profile(a.trace,a.image,a.symbols,snapshot)
    print('AAP linked KINIT/KCORE/MRES startup profile:', report['region_starts'])
    print('Exceptional events:',report['exception_events'])
    print('Ordinary logical-tick costs valid:',report['ordinary_tick_cost_valid'])
    if a.output:
        Path(a.output).write_text(json.dumps(report,indent=2)+'\n')


if __name__ == '__main__':
    main()
