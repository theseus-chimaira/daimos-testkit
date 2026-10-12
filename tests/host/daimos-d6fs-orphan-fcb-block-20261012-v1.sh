#!/bin/sh
# C99 d6fsck emits octal FCB IDs; map each diagnostic to its physical table block.
set -eu
: "${FCB_START:?provide decimal FCB table start from checked superblock}"
: "${FCB_BLOCKS:?provide decimal table length from checked superblock}"
python3 - "$FCB_START" "$FCB_BLOCKS" "$@" <<'PY'
import sys
start, length = map(int, sys.argv[1:3]); ids = sys.argv[3:]
if start < 0 or length < 1 or not ids:
    raise SystemExit('usage: FCB_START=decimal FCB_BLOCKS=decimal script OCTAL_FCB ...')
for value in ids:
    index = int(value, 8)
    block = start + index // 8
    if block >= start + length:
        raise SystemExit(f'FCB {value}: out of table bounds')
    print(f'FCB {value} octal = {index} decimal; logical FCB block {block}, slot {index % 8}')
PY
