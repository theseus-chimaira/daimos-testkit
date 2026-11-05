#!/bin/sh
# ABI and whole-kernel source codegen regression for the AC10/MOVEM fold.
set -eu
: "${DAIMOS_REPO:?}" "${PDP10_PREFIX:?}"
export TMPDIR=${TMPDIR:-$HOME/tmp}
mkdir -p "$TMPDIR"
self=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
work=$(mktemp -d "$TMPDIR/daimos-kcc-preserved-arg-v1175.XXXXXX")
trap 'rm -rf "$work"' EXIT HUP INT TERM
compiler=${V1175_KCC:-$PDP10_PREFIX/bin/kcc}
test -x "$compiler"

"$compiler" -Pgnu99 -O -x=pdp6 -m=gas -S \
    -o "$work/reproducer.s" \
    "$self/daimos-kcc-preserved-arg-v1175.c" \
    > "$work/reproducer-build.log" 2>&1 || {
        cat "$work/reproducer-build.log" >&2
        exit 1
    }

incs=
for sub in boot core drivers fs ipc mm modules proc storage; do
    incs="$incs -I$DAIMOS_REPO/system/kernel/$sub"
done
# shellcheck disable=SC2086
"$compiler" -Pgnu99 -O -x=pdp6 -m=gas $incs -S \
    -o "$work/mm_boot.s" "$DAIMOS_REPO/system/kernel/mm/mm_boot.c" \
    > "$work/mm-build.log" 2>&1 || {
        cat "$work/mm-build.log" >&2
        exit 1
    }

python3 - "$work/reproducer.s" "$work/mm_boot.s" <<'PY'
from pathlib import Path
import re
import sys


def body(filename, symbol):
    source = Path(filename).read_text()
    match = re.search(r'(?m)^' + re.escape(symbol) + r':\s*$', source)
    if match is None:
        raise SystemExit('v1175: missing function ' + symbol)
    remainder = source[match.end():]
    return remainder.split('pushj\t17,slots', 1)[0]


def assert_order(source, store, caller):
    lines = source.splitlines()
    copy = next((i for i, line in enumerate(lines)
                 if re.fullmatch(r'\s*move\s+10,1\s*', line)), -1)
    save = next((i for i, line in enumerate(lines)
                 if re.fullmatch(r'\s*movem\s+10,' +
                                 re.escape(store) + r'\s*', line)), -1)
    load = next((i for i, line in enumerate(lines)
                 if re.fullmatch(r'\s*move\s+1,010\s*', line)), -1)
    if not (copy >= 0 and save > copy and load > save):
        raise SystemExit('v1175: ' + caller +
                         ' lost preserved AC10 before a later call')


source = Path(sys.argv[1]).read_text()
for symbol in ('preserved_arg_before_call', 'preserved_arg_simple'):
    assert_order(body(sys.argv[1], symbol), 'preserved_words', symbol)

kernel = Path(sys.argv[2]).read_text()
match = re.search(r'(?m)^mm_boot_init:\s*$', kernel)
if match is None:
    raise SystemExit('v1175: mm_boot_init missing from KCC output')
function = kernel[match.end():].split('mm_boot_reserve:', 1)[0]
assert_order(function, 'mm_core_words', 'real mm_boot_init')
print('v1175: optimized ABI argument survives global store and call '
      'in minimal and production MM boot sources PASS')
PY
