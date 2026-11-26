#!/bin/sh
set -eu
: "${DAIMOS_REPO:?DAIMOS source checkout required}"
TMPDIR=${TMPDIR:-$HOME/tmp}
PDP10_PREFIX=${PDP10_PREFIX:-$HOME/cross}
export TMPDIR PDP10_PREFIX
mkdir -p "$TMPDIR"
here=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
kit=$(CDPATH= cd -- "$here/../../.." && pwd)
src="$DAIMOS_REPO/system/kernel/proc"
work=$(mktemp -d "$TMPDIR/daimos-bitmap-directory-v1977.XXXXXX")
trap 'echo "v1977 evidence: $work"' EXIT
compile() {
    "$PDP10_PREFIX/bin/kcc" -Pgnu99 -O -x=pdp6 -m=gas \
        -I"$src" -I"$DAIMOS_REPO/system/kernel/mm" \
        -I"$DAIMOS_REPO/system/kernel/core" -I"$PDP10_PREFIX/include" \
        -S "$1" -o "$2"
}
compile "$src/proc_pure_bitmap_directory_v1977.c" "$work/codec.s"
compile "$here/test-native-v1977.c" "$work/test.s"
run_guest() {
    "$PDP10_PREFIX/bin/p10run" --machine "$1" --mode deposit \
        --exec-mode go --start 1000 --timeout 120 \
        --workdir "$work/$2" --name "$2" --expect __test_exit=0 \
        --examine diag_raw_v1977 --examine diag_pattern_v1977 \
        --examine diag_delta_v1977 --examine diag_direction_v1977 \
        --examine diag_rc_v1977 --examine diag_expected_v1977 \
        --examine diag_cases_v1977 --examine diag_good_v1977 \
        --examine diag_refused_v1977 --examine diag_nogain_v1977 \
        --examine diag_reverse_only_v1977 --examine diag_reverse_encode_v1977 \
        --examine diag_both_unsafe_v1977 \
        "$kit/tests/validation/daimos-test-crt0-v1.s" "$work/codec.s" "$3" "$work/test.s"
}
for machine in pdp6 ka10; do
    run_guest "$machine" "directory-$machine-v1977" "$src/proc_pure_bitmap_walk_v1977.s" >"$work/$machine.log" 2>&1 || { tail -60 "$work/$machine.log"; exit 1; }
    cat "$work/$machine.log"
    grep -A1 'EXAMINE__ diag_\(cases\|good\|refused\|nogain\|reverse_only\|reverse_encode\|both_unsafe\)_v1977' \
        "$work/directory-$machine-v1977/directory-$machine-v1977.out"
done
# Independently disable encoder, decoder-mask, decoder-literal and exact
# consumption guards. The guest must execute and reject every mutant.
python3 - "$src/proc_pure_bitmap_walk_v1977.s" "$work" <<'PYMUT'
from pathlib import Path
import sys
s=Path(sys.argv[1]).read_text()
w=Path(sys.argv[2])
for name, changes in {
    'write-fault': [('        jrst    pbmd_return_v1977\npbmd_invalid_v1977:', '        trne    10,2\n        movni   1,4\n        jrst    pbmd_return_v1977\npbmd_invalid_v1977:')],
    'unsafe-encode': [('pbmd_raw_guard_v1977:\n', 'pbmd_raw_guard_v1977:\n        popj 17,\n')],
    'unsafe-decode-mask': [
        ('        camg    1,2\n        jrst    pbmd_decode_hazard_v1977', '        jrst    pbmd_decode_rev_lit_v1977'),
        ('        camge   1,16\n        jrst    pbmd_decode_hazard_v1977', '        jrst    pbmd_decode_fwd_lit_v1977')],
    'unsafe-decode-lit': [
        ('pbmd_decode_rev_lit_v1977:\n', 'pbmd_decode_rev_lit_v1977:\n        jrst pbmd_decode_next_v1977\n'),
        ('pbmd_decode_fwd_lit_v1977:\n', 'pbmd_decode_fwd_lit_v1977:\n        jrst pbmd_decode_next_v1977\n')],
    'unsafe-trailing': [('        came    3,(17)                 ; exact literal consumption/production\n        jrst    pbmd_invalid_v1977\n', '')],
}.items():
    t=s
    for a,b in changes:
        assert t.count(a)==1,(name,a)
        t=t.replace(a,b)
    (w/(name+'.s')).write_text(t)
PYMUT
for mutant in unsafe-encode unsafe-decode-mask unsafe-decode-lit unsafe-trailing; do
    if run_guest pdp6 "$mutant-v1977" "$work/$mutant.s" >"$work/$mutant.log" 2>&1; then
        echo "FAIL: $mutant accepted"; exit 1
    fi
    grep '^FAIL: __test_exit: got ' "$work/$mutant.log"
    echo "PASS: $mutant rejected"
done
compile "$here/test-write-fault-v1977.c" "$work/write-fault-test.s"
"$PDP10_PREFIX/bin/p10run" --machine pdp6 --mode deposit --exec-mode go \
    --start 1000 --timeout 30 --workdir "$work/write-fault-v1977" \
    --name write-fault-v1977 --expect __test_exit=0 \
    "$kit/tests/validation/daimos-test-crt0-v1.s" "$work/codec.s" \
    "$work/write-fault.s" "$work/write-fault-test.s"
"$PDP10_PREFIX/bin/das" -C -O "$work/codec.dobj" "$work/codec.s"
"$PDP10_PREFIX/bin/pdp10-objdump" -h "$work/codec.dobj"
"$PDP10_PREFIX/bin/das" -C -O "$work/walk.dobj" "$src/proc_pure_bitmap_walk_v1977.s"
"$PDP10_PREFIX/bin/pdp10-objdump" -h "$work/walk.dobj"
