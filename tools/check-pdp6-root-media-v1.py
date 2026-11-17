#!/usr/bin/env python3
"""Audit original versus fresh-copy PDP-6 D6FS disk media without repairs.

The host checker flags a DIRTY selected superblock, but DAIMOS may accept
that state. Therefore this tool records rather than diagnoses boot failure.
"""
import argparse
import hashlib
import subprocess
from pathlib import Path


def hash_file(path):
    digest = hashlib.sha256()
    with Path(path).open('rb') as stream:
        while True:
            chunk = stream.read(1024 * 1024)
            if not chunk:
                break
            digest.update(chunk)
    return digest.hexdigest()


def compare(original, copied, members):
    original, copied = Path(original), Path(copied)
    if members not in (1, 2, 3, 4):
        raise ValueError('D6FS members must be between one and four')
    result = {}
    for i in range(members):
        filename = f'dsk{i}.dsk'
        source, target = original / filename, copied / filename
        if not source.is_file() or not target.is_file():
            raise ValueError('missing D6FS member: ' + filename)
        original_hash, copy_hash = hash_file(source), hash_file(target)
        if original_hash != copy_hash:
            raise ValueError('different D6FS media bytes: ' + filename)
        result[filename] = original_hash
    return result


def status(checker, diskdir, members):
    proc = subprocess.run([str(checker), '-n', str(members), '-d', str(diskdir)],
                          capture_output=True, text=True, timeout=30)
    return proc.returncode, (proc.stdout + proc.stderr).strip()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('source_disk_dir')
    parser.add_argument('copy_disk_dir')
    parser.add_argument('--members', type=int, default=4)
    parser.add_argument('--checker', help='optional read-only d6fsck executable')
    args = parser.parse_args()
    hashes = compare(args.source_disk_dir, args.copy_disk_dir, args.members)
    print('Byte-for-byte matching D6FS media:', len(hashes), 'members')
    if args.checker:
        for label, directory in (('original', args.source_disk_dir),
                                 ('copy', args.copy_disk_dir)):
            rc, report = status(args.checker, directory, args.members)
            print(f'{label} d6fsck exit={rc}: {report}')
        print('DIRTY state alone does not prove a DAIMOS root mount failure')


if __name__ == '__main__':
    main()
