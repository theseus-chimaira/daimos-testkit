#!/bin/sh
# Execute the actual native DAIMOS DLINK PURE direct-write predicate
# as PDP-6 code (not a separate reimplementation of its address test).
set -eu
: "${DAIMOS_REPO:?}"
PDP10_PREFIX=${PDP10_PREFIX:-$HOME/cross}
TMPDIR=${TMPDIR:-$HOME/tmp}
export PDP10_PREFIX TMPDIR
mkdir -p "$TMPDIR"
here=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
testkit=$(CDPATH= cd -- "$here/../../.." && pwd)
work=$(mktemp -d "$TMPDIR/dlink-pure-native-v1614.XXXXXX")
trap 'rm -rf "$work"' EXIT HUP INT TERM

python3 - "$DAIMOS_REPO/userland/toolchain/dlink.c" \
    "$work/predicate.c" "$work/mutant.c" <<'PY'
from pathlib import Path
import sys
s = Path(sys.argv[1]).read_text()
a = 'static int\nopcode_writes_ea(unsigned int op)\n{'
b = '\nstatic int\napply_reloc('
assert s.count(a) == 1 and s.count(b) == 1
part = a + s.split(a, 1)[1].split(b, 1)[0]
Path(sys.argv[2]).write_text(part + '\n')
needle = 'return ea >= 020UL && ea >= nl_image_base &&'
assert part.count(needle) == 1
Path(sys.argv[3]).write_text(
    part.replace(needle,
        'return ea >= nl_image_base &&', 1) + '\n')
PY
cat >"$work/preamble.c" <<'EOF'
/* Native PDP-6 test fixture: exact source predicate below. */
typedef unsigned long kword_t;
/* The standard p10run CRT records main's result in this physical word. */
kword_t __test_exit;
static kword_t nl_image_base;
static kword_t nl_text_words;
static kword_t
nd_lh(kword_t word)
{
    return (word >> 18U) & 0777777UL;
}
static kword_t
nd_rh(kword_t word)
{
    return word & 0777777UL;
}
EOF
cat >"$work/main.c" <<'EOF'
int
main(void)
{
    kword_t pop_ac = ((kword_t)0262UL << 27U) | 010UL;
    kword_t movem_ac = ((kword_t)0202UL << 27U) | 010UL;
    kword_t movem_text = ((kword_t)0202UL << 27U) | 020UL;
    kword_t indexed = movem_text | ((kword_t)1UL << 18U);
    kword_t indirect = movem_text | ((kword_t)020UL << 18U);

    nl_image_base = 020UL;
    nl_text_words = 040UL;
    if (definite_text_write(pop_ac) ||
        definite_text_write(movem_ac) ||
        !definite_text_write(movem_text) ||
        definite_text_write(indexed) ||
        definite_text_write(indirect))
        return 1;
    nl_image_base = 0400UL;
    nl_text_words = 010UL;
    if (definite_text_write(movem_text) ||
        !definite_text_write(((kword_t)0202UL << 27U) | 0402UL) ||
        definite_text_write(((kword_t)0202UL << 27U) | 0410UL))
        return 2;
    nl_image_base = 0UL;
    nl_text_words = 040UL;
    if (definite_text_write(pop_ac) ||
        definite_text_write(movem_ac) ||
        !definite_text_write(movem_text))
        return 3;
    return 0;
}
EOF
for case_name in positive unsafe; do
    if [ "$case_name" = positive ]; then
        leaf="$work/predicate.c"
    else
        leaf="$work/mutant.c"
    fi
    cat "$work/preamble.c" "$leaf" "$work/main.c" >"$work/$case_name.c"
    "$PDP10_PREFIX/bin/pdp10-dec-none-gcc" -std=c89 -Os \
        -S "$work/$case_name.c" -o "$work/$case_name.s" \
        >"$work/$case_name.compile.log" 2>&1 || {
        cat "$work/$case_name.compile.log"
        exit 1
    }
done

"$PDP10_PREFIX/bin/p10run" --machine pdp6 --mode deposit \
    --exec-mode go --start 1000 --timeout 30 \
    --workdir "$work/positive-run" --name dlink-pure-v1614 \
    --expect __test_exit=0 \
    "$testkit/tests/validation/daimos-test-crt0-v1.s" \
    "$work/positive.s"

if "$PDP10_PREFIX/bin/p10run" --machine pdp6 --mode deposit \
    --exec-mode go --start 1000 --timeout 30 \
    --workdir "$work/unsafe-run" --name dlink-pure-unsafe-v1614 \
    --expect __test_exit=0 \
    "$testkit/tests/validation/daimos-test-crt0-v1.s" \
    "$work/unsafe.s" >"$work/unsafe.log" 2>&1; then
    echo 'FAIL v1614: native AC0..AC17 unsafe mutant was accepted' >&2
    exit 1
fi
if ! grep -F 'FAIL: __test_exit' "$work/unsafe.log" >/dev/null; then
    cat "$work/unsafe.log" >&2
    exit 1
fi
echo 'PASS v1614 native PDP-6 DLINK PURE address range and unsafe mutant'
