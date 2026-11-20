#!/usr/bin/env python3
"""Replay v1729 physical acceptance and reject corrupted SIMH witnesses.

Usage: verify-mutants-v1729.py GENERATED_RUNNER ADDRESSES SIMH_OUTPUT
The verifier itself is extracted from the generated physical runner,
not reimplemented here. All changed transcripts are temporary files.
"""

from pathlib import Path
import os
import re
import subprocess
import sys
import tempfile


def replay(code, addrpath, transcript):
    return subprocess.run(
        [sys.executable, '-', str(addrpath), str(transcript)],
        input=code, text=True, stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT)


def main():
    if len(sys.argv) != 4:
        raise SystemExit('usage: verify-mutants-v1729.py RUNNER ADDRS SIMH')
    runner, addresses, transcript = (Path(arg).resolve()
                                      for arg in sys.argv[1:])
    body = runner.read_text()
    marker = '''python3 - "$work/addresses" "$work/simh.out" <<'PY'\n'''
    if body.count(marker) != 1:
        raise SystemExit('v1729: physical verifier marker drift')
    code = body.split(marker, 1)[1].split('\nPY\n', 1)[0]
    if 'K02 v1729:' not in code:
        raise SystemExit('v1729: verifier body drift')
    source = transcript.read_text(errors='replace')
    target = dict(line.split() for line in addresses.read_text().splitlines())

    original = replay(code, addresses, transcript)
    if original.returncode:
        raise SystemExit('v1729: original witness fails:\n' +
                         original.stdout[-1800:])
    print('v1729: exact physical transcript acceptance replay PASS')

    temp_root = Path(os.environ.get('TMPDIR') or
                     str(Path.home() / 'tmp'))
    temp_root.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory(
            prefix='v1729-mutants-', dir=str(temp_root)) as directory:
        root = Path(directory)

        def reject(label, text):
            path = root / (label + '.simh')
            path.write_text(text)
            result = replay(code, addresses, path)
            if result.returncode == 0 or 'v1729:' not in result.stdout:
                raise SystemExit('v1729: unsafe mutant not rejected: ' +
                                 label + '\n' + result.stdout[-1500:])
            print('v1729: unsafe mutant rejected:', label)

        if source.count('<P') != 1:
            raise SystemExit('v1729: expected one <P console witness')
        reject('missing-completion', source.replace('<P', '<', 1))

        def mutate_word(name, value):
            address = target[name].lstrip('0')
            pattern = re.compile(
                r'(?m)^(\s*0*' + re.escape(address) +
                r'\s*:\s*)([0-7]+)(?=\s|$)')
            matches = list(pattern.finditer(source))
            if len(matches) != 1:
                raise SystemExit('v1729: missing/ambiguous witness ' + name)
            changed = pattern.sub(
                lambda match: match.group(1) + format(value, '012o'),
                source, count=1)
            if changed == source:
                raise SystemExit('v1729: inert witness mutation ' + name)
            reject(name, changed)

        mutate_word('sess_fails', 0)
        mutate_word('sess_bad', 1)
        mutate_word('exec_postvm', 0)
        mutate_word('provrefuse', 0)
        mutate_word('leasebad', 1)
    print('v1729: six transcript mutants rejected PASS')


if __name__ == '__main__':
    main()
