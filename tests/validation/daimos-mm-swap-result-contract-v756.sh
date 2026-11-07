#!/bin/sh
# Check native transaction result classifications without exercising PI scheduling.
set -eu
: "${DAIMOS_REPO:?}"
: "${PDP10_PREFIX:?}"
export TMPDIR=${TMPDIR:-$HOME/tmp}
mkdir -p "$TMPDIR"
work=$(mktemp -d "$TMPDIR/daimos-mm-swap-result-v756.XXXXXX")
trap 'rm -rf "$work"' EXIT HUP INT TERM
src="$DAIMOS_REPO/system/kernel/proc/proc_swap_pdp6.s"
{ printf '.equ PROC_SWAP_VERIFY_PURE,0\n'; cat "$src"; } > "$work/swap.s"
"$PDP10_PREFIX/bin/das" -C -F -O "$work/swap.dobj" "$work/swap.s"
"$PDP10_PREFIX/bin/pdp10-dec-none-objdump" -t "$work/swap.dobj" > "$work/symbols"
grep -q 'proc_swap_in' "$work/symbols"
# The numeric result contract is shared by the public header and native
# assembly.  The old C implementation was removed when these transactions
# moved into compact PDP-6 leaves; testing its old text is not meaningful.
grep -q '^#define PROC_SWAP_IN_PRESSURE[[:space:]]*1$' "$DAIMOS_REPO/system/kernel/proc/proc_swap.h"
python3 - "$src" <<'PY'
from pathlib import Path
import re
import sys

source = Path(sys.argv[1]).read_text()
start = source.index('\nproc_swap_in_alloc_status:\n')
end = source.index('\nproc_swap_in_restore:\n', start)
part = source[start:end]

def verify(text):
    required = (
        r'camge\s+1,\[-3\]',
        r'jrst\s+proc_swap_in_alloc_clear',
        r'movei\s+7,1',
        r'jumpn\s+7,proc_swap_in_pressure',
        r'proc_swap_in_fail:\s*seto\s+1,',
        r'proc_swap_in_pressure:\s*movei\s+1,1',
    )
    return all(re.search(p, text) for p in required)

assert verify(part), 'native swap-in pressure/fatal result contract changed'
for old, new in (
    ('camge   1,[-3]', 'camge   1,[-4]'),
    ('movei   7,1', 'setz    7,'),
    ('jumpn   7,proc_swap_in_pressure', 'jumpn   7,proc_swap_in_fail'),
    ('proc_swap_in_pressure:\n        movei   1,1',
     'proc_swap_in_pressure:\n        seto    1,'),
):
    assert old in part, 'mutant anchor missing: ' + old
    assert not verify(part.replace(old, new, 1)), 'unsafe mutant accepted'
print('v756: native typed pressure/fatal classification and four mutants PASS')
PY
echo 'v756: native swap-in result contract compiles (liveness separate)'
