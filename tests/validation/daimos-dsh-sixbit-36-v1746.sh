#!/bin/sh
# Exercise production SIXBIT code with native KCC and real PDP-6 simulator.
set -eu
: "${DAIMOS_REPO:?}" "${PDP10_PREFIX:?}"
TMPDIR=${TMPDIR:-$HOME/tmp}
export TMPDIR PATH="$PDP10_PREFIX/bin:$PATH"
mkdir -p "$TMPDIR"
work=$(mktemp -d "$TMPDIR/daimos-dsh-sixbit-v1746.XXXXXX")
incs=''
for dir in boot core drivers fs mm modules proc storage; do
    incs="$incs -I$DAIMOS_REPO/system/kernel/$dir"
done
incs="$incs -I$DAIMOS_REPO/userland/libc -I$DAIMOS_REPO/userland/dsh -I$PDP10_PREFIX/include"
trap 'rm -rf "$work"' EXIT HUP INT TERM
self=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
(
    cd "$work"
    TERM=dumb "$PDP10_PREFIX/bin/kcc" -S -v=nostats -Pgnu99 -O \
        -x=pdp6 -m=gas $incs -R=v1746-test \
        "$self/daimos-dsh-sixbit-36-v1746.c"
    TERM=dumb "$PDP10_PREFIX/bin/kcc" -S -v=nostats -Pgnu99 -O \
        -x=pdp6 -m=gas $incs -R=v1746-s6 \
        "$DAIMOS_REPO/userland/dsh/dsh_s6.c"
)
cat > "$work/stubs.s" <<'ASSEMBLY'
.text
.globl u_put_s6
u_put_s6: seto 1,
        popj 17,
.bss
.globl __test_exit
__test_exit: .block 1
ASSEMBLY
"$PDP10_PREFIX/bin/p10run" --machine pdp6 --mode deposit \
    --exec-mode step --step-limit 500000 --timeout 30 \
    --workdir "$work/run" --name dsh_sixbit_v1746 \
    --expect __test_exit=0 "$self/daimos-test-crt0-v1.s" \
    "$work/stubs.s" "$work/v1746-test.s" "$work/v1746-s6.s" \
    > "$work/run.log" 2>&1 || {
        tail -45 "$work/run.log" >&2
        exit 1
    }
# Mutation: the SIXBIT word boundary must be exactly six characters.
# Replacing the subtract-by-six with subtract-by-five must fail against
# the same unmodified native PDP-6 oracle, not merely change assembly.
python3 - "$DAIMOS_REPO/userland/dsh/dsh_s6.c" "$work/mutant.c" <<'PY'
from pathlib import Path
import sys
s = Path(sys.argv[1]).read_text()
needle = 'rem -= DSH_S6_CHARS_PER_WORD;'
assert s.count(needle) == 2
Path(sys.argv[2]).write_text(s.replace(
    needle, 'rem -= DSH_S6_CHARS_PER_WORD - 1U;'))
PY
(
    cd "$work"
    TERM=dumb "$PDP10_PREFIX/bin/kcc" -S -v=nostats -Pgnu99 -O \
        -x=pdp6 -m=gas $incs -R=v1746-mutant "$work/mutant.c"
)
if "$PDP10_PREFIX/bin/p10run" --machine pdp6 --mode deposit \
    --exec-mode step --step-limit 500000 --timeout 30 \
    --workdir "$work/run-unsafe" --name dsh_sixbit_mutant_v1746 \
    --expect __test_exit=0 "$self/daimos-test-crt0-v1.s" \
    "$work/stubs.s" "$work/v1746-test.s" "$work/v1746-mutant.s" \
    > "$work/unsafe.log" 2>&1; then
    echo 'DSH SIXBIT v1746: invalid word boundary unexpectedly passed' >&2
    exit 1
fi
grep -q '^FAIL:' "$work/unsafe.log" || {
    tail -35 "$work/unsafe.log" >&2
    exit 1
}
echo 'DSH SIXBIT 36 positions, counted conversion and mutant PDP-6: PASS'
