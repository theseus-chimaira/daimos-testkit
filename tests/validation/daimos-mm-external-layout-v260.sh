#!/bin/sh
# Validate the direct-address MM table reservation in a freshly linked map.
set -eu
: "${DAIMOS_REPO:?}"
map=${1:-$DAIMOS_REPO/build/system/boot/pdp6/kcore.map}
: "${map:?}"
[ -f "$map" ] || { echo 'missing KCORE map' >&2; exit 1; }
word_at()
{
    awk -v name="$1" '$1 == name { print $2; exit }' "$map"
}
end=$(word_at __kcore_low_end)
table=$(word_at mm_extents)
capacity=$(word_at mm_extent_capacity)
[ -n "$end" ] && [ -n "$table" ] && [ -n "$capacity" ] || {
    echo 'missing MM boundary or runtime-capacity symbol' >&2; exit 1;
}
[ "$end" = "$table" ] || {
    echo "MM table not directly at KCORE end: $table != $end" >&2; exit 1;
}
# The maximum 136-descriptor table reserves 0420 octal words below KINIT.
end_decimal=$(printf '%d' "0$end")
[ $((end_decimal + 272)) -le $((030000)) ] || {
    echo 'MM table overlaps KINIT image' >&2; exit 1;
}
grep -q 'camge[[:space:]]*7,mm_extent_capacity' "$DAIMOS_REPO/system/kernel/mm/mm_pdp6.s" || {
    echo 'native MM insertion ignores runtime capacity' >&2; exit 1;
}
echo "daimos-mm-external-layout-v260: PASS (end=$end, table=$table, capacity-symbol=$capacity)"
