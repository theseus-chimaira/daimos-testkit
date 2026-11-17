#!/usr/bin/env python3
"""Authenticate a bounded linked-DAIMOS boot-stage opcode profile.

A kernel banner plus module milestone is needed *in addition* to a
complete 512-counter SIMH histogram. This does not certify coverage of
all MRES, interrupts, faults or a representative steady-state workload.
"""
import argparse
import hashlib
import importlib.util
import json
import os
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
PDP10 = Path(os.environ.get('PDP10_TESTKIT_REPO',
                            str(ROOT.parent/'pdp10-testkit')))
spec = importlib.util.spec_from_file_location('report', PDP10/'tools/report-pdp6-opcodes-v1.py')
report = importlib.util.module_from_spec(spec)
spec.loader.exec_module(report)


def validate(raw):
    for token in ('DAIMON', 'PDP6', 'CTY', 'BSET', 'LOADED', 'Step expired', 'PC:'):
        if token not in raw:
            raise ValueError('kernel milestone or bounded stop missing: ' + token)
    # Require coherent banner/module records, not incidental strings.
    import re
    if not (re.search(r'^DAIMON\s+V[0-9]', raw, re.M) and
            re.search(r'^MACH\s+PDP6', raw, re.M) and
            re.search(r'^CTY\s+OK', raw, re.M) and
            re.search(r'^BSET\s+LOADED', raw, re.M)):
        raise ValueError('authenticated kernel/module boot records missing')


def analyze(path):
    raw = Path(path).read_text(errors='replace')
    validate(raw)
    counts = report.read_counts(path)
    active = sum(v != 0 for v in counts.values())
    if active < 12:
        raise ValueError('insufficient opcode diversity')
    return {'schema': 'pdp6-kernel-boot-profile-v1',
            'stage': 'DAIMON through BSET loaded; not full MRES runtime',
            'counter_total': sum(counts.values()),
            'active_opcode_count': active,
            'simh_log_sha256': hashlib.sha256(Path(path).read_bytes()).hexdigest(),
            'opcode_counts': {f'{n:03o}': counts[n] for n in range(512)}}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('log')
    parser.add_argument('--json')
    args = parser.parse_args()
    result = analyze(args.log)
    if args.json:
        Path(args.json).write_text(json.dumps(result, indent=2, sort_keys=True)+'\n')
    print('Verified DAIMON/BSET boot-stage profile:', result['counter_total'],
          'dispatches,', result['active_opcode_count'], 'active opcodes')
    print('This is boot-stage evidence, NOT full KCORE/MRES hotpath coverage')


if __name__ == '__main__':
    main()
