#!/usr/bin/env python3
"""Cross-check actual boot-resident memory by independent guest observations.

Read the real user SYS_MEMINFO resident count, KINIT-patched resident MOVEI
instruction, MM descriptor capacity, and unmodified KCORE linker boundaries.
No test-only resident kernel code or permanent counters are required.
"""

from pathlib import Path
import re
import sys


def require(ok, message):
    if not ok:
        raise SystemExit('v1174: ' + message)


def symbols(text):
    return {name: int(value, 8) for name, value in re.findall(
        r'(?m)^([A-Za-z_][A-Za-z0-9_]*)\s+([0-7]{5,6})\s*$', text)}


def single_examine(simh, address, name):
    regex = r'(?m)^\s*0*%o\s*:\s*([0-7]{1,12})\s*$' % address
    found = re.findall(regex, simh)
    require(len(found) == 1,
            '%s: expected exactly one SIMH examine, got %d' %
            (name, len(found)))
    return int(found[0], 8)


def verify(address_file, simh_file, map_file):
    simh = simh_file
    recorded = {name: int(addr, 8) for name, addr in
                (line.split() for line in address_file.splitlines())}
    km = symbols(map_file)
    for name in ('sys_resident_words_immediate', 'mm_extent_capacity'):
        require(name in recorded and km.get(name) == recorded[name],
                'missing or mismatched map address for ' + name)
    for name in ('__kcore_low_init_end', '__kcore_low_end'):
        require(name in km, 'missing KCORE boundary ' + name)

    user = re.findall(r'R([0-7]{6})S([0-7]{6})<', simh)
    require(len(user) == 1, 'no unique userland SYS_MEMINFO resident marker')
    user_words = int(user[0][0], 8)
    proc_slots = int(user[0][1], 8)
    instruction = single_examine(simh,
                                 recorded['sys_resident_words_immediate'],
                                 'patched SYS_MEMINFO MOVEI')
    # MOVEI 3,imm is opcode 0201 in AC3, no index or indirection.
    require((instruction >> 18) == 0o201140,
            'resident immediate is not MOVEI AC3')
    immediate_words = instruction & 0o777777
    require(immediate_words == user_words,
            'user SYS_MEMINFO=%06o differs from patched MOVEI=%06o' %
            (user_words, immediate_words))

    capacity = single_examine(simh, recorded['mm_extent_capacity'],
                              'actual MM extent capacity')
    # 256K boot has 64 process slots and (2*64+8) MM descriptors.
    require(proc_slots == 64,
            'expected 64 process slots for 256K, observed %d' % proc_slots)
    require(capacity == 2 * proc_slots + 8,
            'MM capacity %d disagrees with %d slots (expected %d)' %
            (capacity, proc_slots, 2 * proc_slots + 8))
    init_end = km['__kcore_low_init_end']
    low_end = km['__kcore_low_end']
    require(0o60 < init_end <= low_end, 'inverted KCORE boundaries')

    core_init = init_end - 0o60
    core_bss = low_end - init_end
    core_total = low_end - 0o60
    mm_table = 2 * capacity
    mres = user_words - core_total - mm_table
    require(mres > 0 and user_words < 0o1000000,
            'impossible permanent MRES size')

    end_exclusive = 0o60 + user_words
    limit = 0o40000
    remaining = limit - end_exclusive
    print('v1174: real SYS_MEMINFO/MOVEI matched: %06o octal = %d words' %
          (user_words, user_words))
    print('v1174: initialized KCORE=%d BSS=%d KCORE total=%d words' %
          (core_init, core_bss, core_total))
    print('v1174: permanent MM descriptor array: %d x 2 = %d words' %
          (capacity, mm_table))
    print('v1174: actually installed permanent MRES images=%d words' % mres)
    print('v1174: occupied low-core last=%06o; 040000-limit headroom=%d words' %
          (end_exclusive - 1, remaining))
    print('v1174: physical user observation and KINIT patch agree PASS')
    if remaining < 0:
        print('v1174: executive 040000 package-limit SHORTFALL=%d words' %
              (-remaining))
    else:
        print('v1174: executive 040000 package-limit spare=%d words' %
              remaining)


if __name__ == '__main__':
    require(len(sys.argv) == 4,
            'usage: VERIFY ADDRESSES SIMH.LOG KCORE.MAP')
    verify(Path(sys.argv[1]).read_text(),
           Path(sys.argv[2]).read_text(errors='replace'),
           Path(sys.argv[3]).read_text())
