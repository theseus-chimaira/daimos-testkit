#!/bin/sh
set -eu
: "$PDP10_PREFIX"
: "$DAIMOS_REPO"
: "$TMPDIR"

work="$TMPDIR/daimos-p10fold-build-v1-$$"
fold_out="$work/folded.out"
base_out="$work/baseline.out"
empty="$work/p10fold-empty.sh"
trap 'rm -rf "$work"' EXIT HUP INT TERM
mkdir -p "$work"

cat > "$empty" <<'EOS'
#!/bin/sh
set -eu
plan=
while [ "$#" -gt 0 ]; do
        case "$1" in
        -P) plan=$2; shift 2 ;;
        -m) shift 2 ;;
        *) shift ;;
        esac
done
test -n "$plan"
printf '%s\n' P10FOLD1 > "$plan"
EOS
chmod +x "$empty"

make -C "$DAIMOS_REPO/system/boot/pdp6" permanent-size \
        BUILD_ROOT="$work/folded" PDP10_PREFIX="$PDP10_PREFIX" \
        >"$fold_out" 2>&1 || :
make -C "$DAIMOS_REPO/system/boot/pdp6" permanent-size \
        BUILD_ROOT="$work/baseline" PDP10_PREFIX="$PDP10_PREFIX" \
        P10FOLD="$empty" >"$base_out" 2>&1 || :

fold_kcore=$(awk '$1 == "KCORE" { print $3; exit }' "$fold_out")
base_kcore=$(awk '$1 == "KCORE" { print $3; exit }' "$base_out")
fold_total=$(awk '$1 == "KCORE+MRES" { print $3; exit }' "$fold_out")
base_total=$(awk '$1 == "KCORE+MRES" { print $3; exit }' "$base_out")
plan="$work/folded/system/boot/pdp6/kcore.fold"

for v in "$fold_kcore" "$base_kcore" "$fold_total" "$base_total"; do
        case "$v" in
        ''|*[!0-9]*)
                cat "$fold_out" "$base_out" >&2
                echo "p10fold-build: could not parse size output" >&2
                exit 1
                ;;
        esac
done

test -f "$plan" || {
        echo "p10fold-build: missing kcore.fold" >&2
        exit 1
}
test "$(sed -n '1p' "$plan")" = P10FOLD1 || {
        echo "p10fold-build: bad fold plan header" >&2
        exit 1
}

plan_words=0
folds=0
while IFS='	' read -r kind donor doff anchor aoff words rest; do
        [ "$kind" = FOLD ] || continue
        [ -z "$rest" ] || {
                echo "p10fold-build: malformed fold plan" >&2
                exit 1
        }
        plan_words=$((plan_words + 0$words))
        folds=$((folds + 1))
done < "$plan"

saved_kcore=$((base_kcore - fold_kcore))
saved_total=$((base_total - fold_total))
if [ "$folds" -eq 0 ] || [ "$plan_words" -lt 5 ]; then
        cat "$plan" >&2
        echo "p10fold-build: expected at least 5 safe planned words, got $plan_words" >&2
        exit 1
fi
if [ "$saved_kcore" -ne "$plan_words" ] || [ "$saved_total" -ne "$plan_words" ]; then
        cat "$fold_out" "$base_out" "$plan" >&2
        echo "p10fold-build: plan=$plan_words kcore=$saved_kcore total=$saved_total" >&2
        exit 1
fi
printf 'p10fold-build: %d folds save %d KCORE/permanent words: PASS\n' \
        "$folds" "$plan_words"
