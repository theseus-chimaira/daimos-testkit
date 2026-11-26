#!/usr/bin/env python3
"""Verify the common 062 decoder, actual boot image and all Stage1 layouts."""
import argparse
from pathlib import Path
import struct
import subprocess

ORIGIN = 0o62
STAGE1 = 0o60
WORDS = 53
DEVICES = ('ptr', 'dtc', 'dsk', 'drm', 'mtc')


def symbols(path):
    result = {}
    for line in path.read_text(encoding='ascii').splitlines():
        fields = line.split()
        if len(fields) == 2 and all(c in '01234567' for c in fields[1]):
            result[fields[0]] = int(fields[1], 8)
    return result


def check_stage1(repo, das, build, work):
    k = symbols(build / 'kcore.map')
    assert k['d6b_image_start_v1458'] == ORIGIN
    assert k['d6codec_block_core_v1458'] == ORIGIN
    assert k['d6b_image_end_v1458'] == ORIGIN + WORDS
    stream = [int(w, 8) for w in (build / 'kcore.stream').read_text().splitlines()[2:]]
    assert len(stream) == k['__kcore_low_init_end'] - ORIGIN
    image = stream[:WORDS]
    work.mkdir(parents=True, exist_ok=True)
    for device in DEVICES:
        raw = work / (device + '-v1961.raw')
        labels = work / (device + '-v1961.labels')
        source = repo / 'system/stand/pdp6' / device / 'stage1.s'
        subprocess.run([str(das), '-F', '-K', '-L', str(labels),
                        '-O', str(raw), str(source)], check=True)
        s = symbols(labels)
        start, end = (s['d6b_image_start_v1458'], s['d6b_image_end_v1458'])
        assert end - start == WORDS, device
        # BLT copies forward, so a lower destination may overlap the
        # source (MTC). A higher overlapping destination would corrupt it.
        assert ORIGIN <= STAGE1 + start or ORIGIN >= STAGE1 + end, (device, 'unsafe forward BLT')
        assert STAGE1 + s['stage1_handoff'] >= ORIGIN + WORDS, (device, 'handoff overlap')
        for label in ('bad_tape', 'stage1_fail_b1', 'fail_decompress',
                      'stage1_enter_kinit', 'entry_addr', 'kinit_stack_base',
                      'compressed_words', 'member_count'):
            if label in s:
                assert STAGE1 + s[label] >= ORIGIN + WORDS, (device, label)
        # DAS -K emits DXR1: two header words followed by the
        # initialized image and relocation records. The fixed decoder
        # contains no relocations, so its image must match KCORE exactly.
        raw_words = [w[0] for w in struct.iter_unpack('<Q', raw.read_bytes())]
        assert raw_words[0] >> 18 == 0o447062, device
        assert end <= raw_words[1] >> 18, device
        assert raw_words[2 + start:2 + end] == image, (device, 'decoder bytes differ')
        print('PASS %s: source %06o, handoff %06o, identical %d words' %
              (device, STAGE1 + start, STAGE1 + s['stage1_handoff'], WORDS))
    init = symbols(build / 'kinit.map')
    payload = [int(w, 8) for w in (build / 'kinit.words').read_text().splitlines()[2:]]
    a = init['__kcore_load_begin'] - init['__kinit_image_start']
    b = init['__kcore_load_end'] - init['__kinit_image_start']
    assert payload[a:b] == stream, 'embedded KCORE differs'
    print('PASS embedded KCORE: %d words at %06o' % (len(stream), ORIGIN))


def main():
    p = argparse.ArgumentParser()
    p.add_argument('repo', type=Path)
    p.add_argument('das', type=Path)
    p.add_argument('build', type=Path)
    p.add_argument('work', type=Path)
    a = p.parse_args()
    check_stage1(a.repo, a.das, a.build, a.work)


if __name__ == '__main__':
    main()
