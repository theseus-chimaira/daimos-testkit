#!/bin/sh
# v1100: source-linked PDP-6 DPY replacement preserves the first MM error.
set -eu
: "${DAIMOS_REPO:?}" "${PDP10_PREFIX:?}"
export TMPDIR=${TMPDIR:-$HOME/tmp}
mkdir -p "$TMPDIR"
self=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
work=$(mktemp -d "$TMPDIR/daimos-dpy-typed-v1100.XXXXXX")
trap 'rm -rf "$work"' EXIT HUP INT TERM
printf '.text\n.globl dpy_write_words\n' > "$work/source.s"
sed -n '/^dpy_write_words:$/,/^dpy_putchar:$/p' \
    "$DAIMOS_REPO/system/kernel/drivers/dpy_io.s" | sed '$d' >> "$work/source.s"
python3 - "$self/daimos-dpy-replace-v874.s" "$work" <<'PY'
from pathlib import Path
import sys

fixture = Path(sys.argv[1]).read_text()
work = Path(sys.argv[2])
src = (work / 'source.s').read_text()
assert src.count('dpy_list_rollback_v874:\n') == 1
assert src.count('        movem 1,(17)\n        move 1,012') == 1
assert src.count('        move 1,(17)\n        sub 17,kconst_1_1') == 1

for code, expected in ((5, '-5'), (4, '-4')):
    f = fixture
    if code == 4:
        assert f.count(' movni 1,5') == 1
        f = f.replace(' movni 1,5', ' movni 1,4')
        assert f.count(' camn 1,[-5]') == 1
        f = f.replace(' camn 1,[-5]', ' camn 1,[-4]')
    (work / ('fixture-' + str(code) + '.s')).write_text(f)

mutants = {
    'collapse': (
        '        move 1,(17)\n        sub 17,kconst_1_1',
        '        seto 1,\n        sub 17,kconst_1_1'),
    'lost-first-error': (
        '        movem 1,(17)\n        move 1,012',
        '        move 1,(17)\n        move 1,012'),
}
for name, (old, new) in mutants.items():
    assert src.count(old) == 1, name
    (work / ('unsafe-' + name + '.s')).write_text(src.replace(old, new, 1))
PY

run_case() {
    name=$1
    src=$2
    code=$3
    "$PDP10_PREFIX/bin/p10run" --machine pdp6 --mode deposit \
        --exec-mode step --start 1000 --step-limit 300000 --timeout 20 \
        --workdir "$work/run-$name" --name "dpy-v1100-$name" \
        --expect __test_exit=0 \
        "$self/daimos-test-crt0-v1.s" "$src" \
        "$work/fixture-$code.s" > "$work/log-$name" 2>&1
}

for code in 5 4; do
    if ! run_case "positive-$code" "$work/source.s" "$code"; then
        tail -50 "$work/log-positive-$code" >&2
        exit 1
    fi
done
for variant in collapse lost-first-error; do
    if run_case "unsafe-$variant" "$work/unsafe-$variant.s" 5; then
        echo "v1100: unsafe $variant unexpectedly passed" >&2
        exit 1
    fi
done
echo 'v1100: DPY old-MM -5/-4 survives rollback; two unsafe mutants rejected PASS'
