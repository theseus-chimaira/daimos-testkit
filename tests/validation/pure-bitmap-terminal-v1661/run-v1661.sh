#!/bin/sh
# Test-only v1661 compressed PURE owner terminal, original PDP-6 MM free.
set -eu
: "${DAIMOS_REPO:?DAIMOS source worktree required}"
TMPDIR=${TMPDIR:-$HOME/tmp}
PDP10_PREFIX=${PDP10_PREFIX:-$HOME/cross}
export TMPDIR PDP10_PREFIX
mkdir -p "$TMPDIR"
here=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
kit=$(CDPATH= cd -- "$here/../../.." && pwd)
src="$DAIMOS_REPO/system/kernel"
work=$(mktemp -d "$TMPDIR/daimos-bitmap-terminal-v1661.XXXXXX")
trap 'echo "v1661 terminal evidence: $work"' EXIT HUP INT TERM
inc="-I$src/proc -I$src/mm -I$src/core -I$src/fs -I$src/storage -I$src/modules -I$src/drivers -I$PDP10_PREFIX/include"

if [ "${V1661_SKIP_BASELINE:-0}" != 1 ]; then
    sh "$kit/tests/validation/pure-bitmap-decode-v1660/run-v1660.sh" \
        >"$work/v1660.log" 2>&1
    echo 'v1661: original v1660 decoder and v1659 MM baseline PASS'
fi

# Extract the exact real MM descriptor delete/find/free leaves, not an
# imitation C allocator. Fail if original assembler structure drifts.
python3 - "$src/mm/mm_pdp6.s" "$work/real-mm-free.s" <<'PY'
from pathlib import Path
import sys
s = Path(sys.argv[1]).read_text(encoding='ascii')


def leaf(start, stop):
    if s.count(start) != 1 or s.count(stop) != 1:
        raise SystemExit('v1661 original MM leaf boundary drift')
    return start + s.split(start, 1)[1].split(stop, 1)[0]


body = leaf('mm_delete:\n', '\n; Find a fitting free gap.') + '\n'
body += leaf('mm_free:\n', '\n; int mm_process_transfer_pinned')
for label in ('mm_delete:', 'mm_find_base:', 'mm_free:',
              'mm_free_inval:', 'mm_free_busy:'):
    if label not in body:
        raise SystemExit('v1661 missing original MM label ' + label)
Path(sys.argv[2]).write_text('.text\n.globl mm_free\n' + body,
                              encoding='ascii')
PY

"$PDP10_PREFIX/bin/kcc" -Pgnu99 -O -x=pdp6 -m=gas \
    -DDAIMOS_PURE_BITMAP_TERMINAL_V1661=1 \
    -Dmm_free=mm_terminal_free_v1661 $inc \
    -S "$src/proc/proc_pure_bitmap_terminal_v1661.c" \
    -o "$work/terminal.s" >"$work/terminal-compile.log" 2>&1 || {
    cat "$work/terminal-compile.log" >&2
    exit 1
}
"$PDP10_PREFIX/bin/kcc" -Pgnu99 -O -x=pdp6 -m=gas $inc \
    -S "$here/test-native-v1661.c" \
    -o "$work/test.s" >"$work/test-compile.log" 2>&1 || {
    cat "$work/test-compile.log" >&2
    exit 1
}
"$PDP10_PREFIX/bin/das" -F -C -O "$work/terminal.dobj" \
    "$work/terminal.s"
"$PDP10_PREFIX/bin/pdp10-dec-none-objdump" -h \
    "$work/terminal.dobj" >"$work/terminal-size.log"

run_guest() {
    name=$1
    candidate=$2
    log=$3
    "$PDP10_PREFIX/bin/p10run" --machine pdp6 --mode deposit \
        --exec-mode go --start 1000 --timeout 30 \
        --workdir "$work/$name" --name "$name" --expect __test_exit=0 \
        "$kit/tests/validation/daimos-test-crt0-v1.s" \
        "$work/real-mm-free.s" "$candidate" "$work/test.s" \
        >"$log" 2>&1
}
run_guest bitmap-terminal-v1661 "$work/terminal.s" "$work/native.log" || {
    tail -65 "$work/native.log" >&2
    exit 1
}
echo 'v1661: real MM-free terminal, 18 refusals, upper-boundary and module owner PASS'

# Executed unsafe mutation: ignore duplicate compressed owners. The
# test must reject the corrupted state before any owner is released.
python3 - "$src/proc/proc_pure_bitmap_terminal_v1661.c" \
    "$work/duplicate-mutant.c" <<'PY'
from pathlib import Path
import sys
s = Path(sys.argv[1]).read_text(encoding='ascii')
old = '++found != 1U || type != MM_TYPE_PACKED_PROCESS'
finish = 'if (found != 1U) {'
if s.count(old) != 1 or s.count(finish) != 1:
    raise SystemExit('v1661 duplicate owner mutation anchor drift')
s = s.replace(old,
              '++found == 0U || type != MM_TYPE_PACKED_PROCESS', 1)
s = s.replace(finish, 'if (found == 0U) {', 1)
Path(sys.argv[2]).write_text(s, encoding='ascii')
PY
"$PDP10_PREFIX/bin/kcc" -Pgnu99 -O -x=pdp6 -m=gas \
    -DDAIMOS_PURE_BITMAP_TERMINAL_V1661=1 \
    -Dmm_free=mm_terminal_free_v1661 $inc \
    -S "$work/duplicate-mutant.c" -o "$work/duplicate-mutant.s" \
    >"$work/mutant-compile.log" 2>&1
if run_guest bitmap-terminal-duplicate-mutant-v1661 \
    "$work/duplicate-mutant.s" "$work/mutant.log"; then
    echo 'FAIL: unsafe duplicate-owner terminal mutant accepted' >&2
    exit 1
fi
grep -q '^FAIL: __test_exit: got ' "$work/mutant.log" || {
    tail -55 "$work/mutant.log" >&2
    exit 1
}
echo 'v1661: executed unsafe duplicate-owner mutant rejected'
