#!/bin/sh
# Guard the lazy-function-pool DSH memory stage; the production target
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
if test $((0$image)) -gt $((035671)); then
    echo "FAIL: DSH image regressed above 035671 octal words: $image" >&2
    exit 1
fi
if test $((0$bss)) -gt $((005013)); then
    echo "FAIL: DSH BSS regressed above 005013 octal words: $bss" >&2
    exit 1
fi
for symbol in u_s6_eq u_s6_pack u_text_open u_text_fields u_text_key; do
    if grep -Eq "^$symbol[[:space:]]" "$DSH_MAP"; then
        echo "FAIL: DSH still links unused helper: $symbol" >&2
        exit 1
    fi
done
echo "PASS: DSH image $image, BSS $bss octal; unused helpers excluded"
echo "PASS: production 036000 image limit satisfied"
# Exact EXEC VM words before and after the PDP-6 02000-word extent alignment.
# The source shrink passes the image gate but does not meet 32K residency.
vm=$((0$image + 0$bss + 02020))
aligned=$(((vm + 01777) & ~01777))
printf 'VM: %o octal required, %o octal allocated\n' "$vm" "$aligned"
if test "$aligned" -gt $((046000)); then
    echo "FAIL: DSH VM exceeds 046000 octal allocation: $aligned" >&2
    exit 1
fi
if test -n "${KCORE_MAP:-}"; then
    kcore=$(awk '$1 == "__kcore_low_end" { print $2; exit }' "$KCORE_MAP")
    case "$kcore" in
    ''|*[!0-7]*) echo "FAIL: missing octal __kcore_low_end" >&2; exit 1 ;;
    esac
    floor=$((0$kcore + aligned))
    printf '32K occupancy lower bound: %o octal / 100000 octal\n' "$floor"
    if test "$floor" -gt $((0100000)); then
        printf '32K: INSUFFICIENT even before other resident allocations (%o octal excess)\n' \
            "$((floor - 0100000))"
    else
        echo '32K: static lower bound fits; full boot and other allocations still required'
    fi
fi
