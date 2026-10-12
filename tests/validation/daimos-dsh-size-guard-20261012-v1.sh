#!/bin/sh
# Guard the first low-risk DSH shrinkage stage; the production target
# remains 036000 octal image words. This temporary cap prevents regression.
set -eu
: "${DSH_DXR:?set DSH_DXR to the newly linked DSH image}"
: "${DSH_MAP:?set DSH_MAP to the matching linker map}"
: "${DXRCHECK:=dxrcheck}"
record=$("$DXRCHECK" "$DSH_DXR")
image=$(printf '%s\n' "$record" |
    sed -n 's/^DXR image=\([0-7][0-7]*\).*/\1/p')
bss=$(printf '%s\n' "$record" |
    sed -n 's/^DXR image=[0-7][0-7]* bss=\([0-7][0-7]*\).*/\1/p')
if test -z "$image" || test -z "$bss"; then
    echo "FAIL: dxrcheck did not report octal image/BSS sizes" >&2
    exit 1
fi
if test $((0$image)) -gt $((036054)); then
    echo "FAIL: DSH image regressed above 036054 octal words: $image" >&2
    exit 1
fi
if test $((0$bss)) -gt $((015241)); then
    echo "FAIL: DSH BSS regressed above 015241 octal words: $bss" >&2
    exit 1
fi
for symbol in u_s6_eq u_text_fields u_text_key; do
    if grep -Eq "^$symbol[[:space:]]" "$DSH_MAP"; then
        echo "FAIL: DSH still links unused helper: $symbol" >&2
        exit 1
    fi
done
echo "PASS: DSH image $image, BSS $bss octal; unused helpers excluded"
echo "NOTE: production 036000 image limit is not yet satisfied"
