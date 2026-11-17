#!/usr/bin/env python3
"""Inventory all DAIMOS maintained assembler, without guessing dynamic coverage.

System and userland are source roots; build products are listed separately.
Unknown mnemonic-like tokens are preserved for manual classification.
"""
import argparse
from collections import Counter, defaultdict
from pathlib import Path
import re
import importlib.util
import os

ROOT = Path(__file__).resolve().parents[1]
PDP10 = Path(os.environ.get('PDP10_TESTKIT_REPO',
                            str(ROOT.parent/'pdp10-testkit')))
SPEC = importlib.util.spec_from_file_location('kernel_inventory',
                                               PDP10/'tools/aap-kernel-coverage-v1.py')
KERNEL = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(KERNEL)
LABEL = re.compile(r'^(?:[a-z_.$%][\w.$%]*|[0-9]+):\s*', re.I)
TOKEN = re.compile(r'^([a-z][a-z0-9]*)\b',re.I)
# PDP-10 instruction forms that occur in maintained DAIMOS source but were
# absent from the earlier kernel-focused hand-built inventory. Listing an
# opcode here does NOT establish AAP functional or timing test coverage.
ADDITIONAL_OPCODES = set('''setzm hrli sojg aoja tlc setom idivi hrroi setzb andcmi
    tloa aoje sojn tdza hrri sojl setm divi trna soje muli soja andcam
    addb skipa setcm iorb movns ori andb sosle hrlzm hlre hrloi aojl
    hrlzi hrlzs movms sojle hlrzm andcai hrrzm exch sojge setzi aojn
    sosn setob'''.split())
# UUO is a generic unimplemented-operation mnemonic and HALT is a privileged
# halt pseudoinstruction; keep them visible separately pending syntax audit.
SPECIAL_FORMS = {'uuo', 'halt'}
KNOWN = (KERNEL.BASE |
         {name for group in KERNEL.GROUPS.values() for name in group} |
         ADDITIONAL_OPCODES)


def inventory(root):
    results = defaultdict(Counter)
    unknown = Counter()
    special = Counter()
    files = Counter()
    for section in ('system','userland','build'):
        base = root/section
        if not base.is_dir():
            continue
        for path in sorted(base.rglob('*')):
            if not path.is_file() or path.suffix.lower() != '.s':
                continue
            files[section] += 1
            for raw in path.read_text(errors='replace').splitlines():
                line = raw.split(';',1)[0].split('/*',1)[0].strip()
                if not line or line.startswith(('.', '#','*','//')):
                    continue
                while LABEL.match(line):
                    line = LABEL.sub('',line,count=1).strip()
                found = TOKEN.match(line)
                if not found:
                    continue
                word = found.group(1).lower()
                if word in KNOWN:
                    results[section][word] += 1
                elif word in SPECIAL_FORMS and section != 'build':
                    special[word] += 1
                elif section != 'build':
                    unknown[word] += 1
    return files,results,unknown,special


def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('repository',type=Path,nargs='?',default=ROOT.parent/'DAIMOS')
    args = p.parse_args()
    files,counts,unknown,special = inventory(args.repository)
    verified = KERNEL.verified_family_names()
    print('DAIMOS static assembler inventory (not executable coverage)')
    for section in ('system','userland','build'):
        found = counts[section]
        hits = sum(n for word,n in found.items() if word in verified)
        print('%s: files=%d known-references=%d fixture-label-matched=%d' %
              (section, files[section],sum(found.values()),hits))
    unresolved = sum(unknown.values())
    recognized = sum(counts[section].total() for section in ('system','userland'))
    print('special opcode/pseudoinstruction references: %d (%s)' % (sum(special.values()), ', '.join('%s:%d' % item for item in sorted(special.items()))))
    print('maintained-source unclassified tokens: %d across %d names' % (unresolved, len(unknown)))
    print('all identified source instruction/special-form candidates: %d' % (recognized + unresolved + sum(special.values())))
    print('WARNING: fixture-label matches are mnemonic proxies, NOT tested opcode/mode coverage')
    print('Maintained source mnemonic counts / fixture-label matches:')
    combined = counts['system']+counts['userland']
    for mnemonic,n in combined.most_common():
        print('%s\t%d\t%s' %(mnemonic.upper(),n,'fixture' if mnemonic in verified else 'UNMATCHED'))
    print('Unclassified leading tokens (potential macros or missing opcode names):')
    for name,n in unknown.most_common(35):
        print('%s\t%d' %(name,n))
    print('WARNING: static proxy; unknown tokens and compiler output are not certified.')


if __name__=='__main__':
    main()
