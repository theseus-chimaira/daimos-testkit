#!/usr/bin/env python3
"""Reject obviously incomplete SIMH opcode dispatch snapshots.

Passing this gate is a NECESSARY, not sufficient, condition for proving
DAIMOS KCORE runtime coverage. Image/PC provenance and MRES execution
must be established independently; a varied bootstrap is not a kernel.
"""
import argparse
from pathlib import Path
import importlib.util
import os

ROOT = Path(__file__).resolve().parents[1]
PDP10 = Path(os.environ.get('PDP10_TESTKIT_REPO',
                            str(ROOT.parent/'pdp10-testkit')))
spec = importlib.util.spec_from_file_location('report', PDP10 / 'tools/report-pdp6-opcodes-v1.py')
report = importlib.util.module_from_spec(spec)
spec.loader.exec_module(report)


def check(path, minimum_distinct=12):
    text = Path(path).read_text(errors='replace')
    if 'Step expired' not in text or 'PC:' not in text:
        raise ValueError('bounded stop and final PC not demonstrated')
    counts = report.read_counts(path)
    active = [(op, n) for op, n in counts.items() if n]
    if len(active) < minimum_distinct:
        raise ValueError('bootstrap-only/inadequate opcode diversity (%d distinct)' % len(active))
    if sum(n for _, n in active) <= 0:
        raise ValueError('no dispatched instructions')
    return active


def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('simh_log')
    args = p.parse_args()
    active = check(args.simh_log)
    print('SIMH candidate runtime profile:', len(active), 'distinct opcodes')
    print('NOT a proof of KCORE/MRES execution; linked-image evidence still required')


if __name__ == '__main__':
    main()
