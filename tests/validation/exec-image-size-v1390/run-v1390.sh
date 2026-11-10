#!/bin/sh
# Isolated PDP-6 size gate for the shared EXEC / PURE loader experiment.
# No production Makefile, KCORE object or raw swap source is modified.
set -eu
: "${DAIMOS_REPO:?}"
PDP10_PREFIX=${PDP10_PREFIX:-$HOME/cross}
TMPDIR=${TMPDIR:-$HOME/tmp}
export TMPDIR PDP10_PREFIX
testkit=$(CDPATH= cd -- "$(dirname "$0")/../../.." && pwd)
work="$TMPDIR/exec-image-size-v1390"
mkdir -p "$work"

as="$PDP10_PREFIX/bin/das"
dump="$PDP10_PREFIX/bin/pdp10-objdump"
loader="$DAIMOS_REPO/system/kernel/proc"

python3 "$testkit/tests/validation/exec-image-cutover-v1388/make-candidate-v1388.py" \
    "$loader/exec_load.s" "$work/exec-candidate-v1390.s"
"$as" -C -O "$work/original.dobj" "$loader/exec_load.s"
"$as" -C -O "$work/candidate.dobj" "$work/exec-candidate-v1390.s"
"$as" -C -O "$work/shared.dobj" "$loader/exec_image_common_v1386.s"

# The old 50-word FULL loader is standalone and relies on constants
# normally supplied by its enclosing swap assembler unit.
{
    printf '.text\n'
    printf '.equ EXEC_DXR_F_COMPRESSED,0100000\n'
    printf '.equ EXEC_USER_ORIGIN,020\n'
    sed -n '/^proc_swap_reload_pure:$/,/^\/\* Provider-independent backing immutability guards/p' \
        "$loader/proc_pure_backing_pdp6.s" | sed '$d'
} > "$work/full-old-v1390.s"
"$as" -C -O "$work/full-old.dobj" "$work/full-old-v1390.s"

words()
{
    "$dump" -h "$1" | sed -n 's/^sections: text=\([0-9]*\).*/\1/p'
}
old=$(words "$work/original.dobj")
candidate=$(words "$work/candidate.dobj")
shared=$(words "$work/shared.dobj")
full_old=$(words "$work/full-old.dobj")
bounded=0
symbol=exec_image_full_backing_v1389
shared_budget=212
adapter_budget=51
combined_budget=98
if "$dump" -t "$work/shared.dobj" |
    grep -q 'exec_image_full_bounded_v1391'; then
    bounded=1
    symbol=exec_image_full_bounded_v1391
    shared_budget=235
    adapter_budget=74
    combined_budget=121
fi
core_octal=$("$dump" -t "$work/shared.dobj" |
    awk -v wanted="$symbol" '$NF == wanted {
        split($4, halves, ",,");
        print halves[2];
    }')
test -n "$core_octal"
# Object symbols use octal addresses. Prefix with 0 to select octal
# arithmetic in the POSIX shell and convert to decimal TEXT words.
core=$((0$core_octal))
adapter=$((shared - core))
total=$((candidate + core))
delta=$((total - old))
combined_delta=$((total + adapter - old - full_old))

printf 'EXEC original: %s words\n' "$old"
printf 'EXEC candidate: %s words\n' "$candidate"
printf 'Shared parser+payload: %s words\n' "$core"
printf 'Shared FULL/PREFIX adapter: %s words\n' "$adapter"
printf 'Original PURE FULL reload: %s words\n' "$full_old"
printf 'Shared EXEC delta: %+d words\n' "$delta"
printf 'Shared EXEC + FULL replacement delta: %+d words\n' \
    "$combined_delta"
printf 'Bounded FULL callback: %s\n' "$bounded"

# Pin this experiment to the measured isolated baseline. Any growth
# requires an explicit new cost review rather than silent KCORE adoption.
test "$old" -eq 183
test "$candidate" -le 119
test "$core" -le 161
test "$shared" -le "$shared_budget"
test "$full_old" -eq 50
test "$adapter" -le "$adapter_budget"
test "$delta" -le 97
test "$combined_delta" -le "$combined_budget"

case "$("$dump" -h "$work/shared.dobj")" in
    *'data=0 bss=0'*) ;;
    *) echo 'shared loader allocated static DATA/BSS' >&2; exit 1 ;;
esac
printf '%s\n' 'PASS exec-image-size-v1390 (unlinked component budget)'
