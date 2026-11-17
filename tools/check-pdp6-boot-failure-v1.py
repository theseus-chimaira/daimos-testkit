#!/usr/bin/env python3
"""Identify a real DAIMOS fatal root boot, never promote its opcode count."""
import argparse
import re
from pathlib import Path


def classify(raw):
    if not re.search(r'^DAIMON\s+V[0-9]', raw, re.M):
        raise ValueError('DAIMOS boot not established')
    if re.search(r'^\?RT\s*$', raw, re.M):
        if not re.search(r'^HALT instruction', raw, re.M):
            raise ValueError('root failure reported without observed HALT')
        pc = re.search(r'^PC:\s*([0-7]{1,6})\s*$', raw, re.M)
        if not pc:
            raise ValueError('root failure missing final PC')
        return {'status': 'fatal-root-boot', 'diagnostic': '?RT',
                'pc_octal': pc.group(1).zfill(6),
                'meaning': 'root mount or regular /SYSTEM/INIT validation failed'}
    if re.search(r'^HALT instruction', raw, re.M):
        raise ValueError('unclassified DAIMOS HALT')
    raise ValueError('no recognized root boot failure')


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('log')
    args = parser.parse_args()
    print(classify(Path(args.log).read_text(errors='replace')))


if __name__ == '__main__':
    main()
