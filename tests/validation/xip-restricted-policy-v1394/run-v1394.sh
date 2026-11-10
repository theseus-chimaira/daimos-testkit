#!/bin/sh
# Host C89 and native PDP-6 checks against the identical staged XIP policy.
set -eu
: "${DAIMOS_REPO:?}"
PDP10_PREFIX=${PDP10_PREFIX:-$HOME/cross}
export TMPDIR="${TMPDIR:-$HOME/tmp}" PDP10_PREFIX
here=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
work=$(mktemp -d "$TMPDIR/daimos-xip-policy-v1394.XXXXXX")
trap 'rm -rf "$work"' EXIT HUP INT TERM
src="$DAIMOS_REPO/system/kernel/proc/proc_xip_policy_v1394.c"
hdr="$DAIMOS_REPO/system/kernel/proc"
"${CC:-cc}" -std=c89 -Wall -Wextra -Werror \
    -I"$hdr" -I"$DAIMOS_REPO/system/kernel/core" \
    "$src" "$here/test-v1394.c" -o "$work/xip-host-v1394"
"$work/xip-host-v1394"
echo 'PASS v1394: host restricted-XIP policy'

"$PDP10_PREFIX/bin/kcc" -Pgnu99 -O -x=pdp6 -m=gas \
    -I"$hdr" -I"$DAIMOS_REPO/system/kernel/core" \
    -S "$src" -o "$work/proc-xip-policy-v1394.s"
"$PDP10_PREFIX/bin/kcc" -Pgnu99 -O -x=pdp6 -m=gas \
    -I"$hdr" -I"$DAIMOS_REPO/system/kernel/core" \
    -S "$here/test-v1394.c" -o "$work/test-v1394.s"
"$PDP10_PREFIX/bin/das" -C -O "$work/proc-xip-policy-v1394.dobj" \
    "$work/proc-xip-policy-v1394.s"
sections=$("$PDP10_PREFIX/bin/pdp10-objdump" -h \
    "$work/proc-xip-policy-v1394.dobj")
echo "$sections"
case "$sections" in
    *'data=0 bss=0'*) ;;
    *) echo 'FAIL v1394: policy has static DATA/BSS' >&2; exit 1 ;;
esac
"$PDP10_PREFIX/bin/p10run" --machine pdp6 --mode deposit \
    --exec-mode go --start 1000 --timeout 30 \
    --workdir "$work/guest" --name xip-policy-v1394 \
    --expect __test_exit=0 \
    "$here/../daimos-test-crt0-v1.s" "$work/proc-xip-policy-v1394.s" \
    "$work/test-v1394.s"
echo 'PASS v1394: native PDP-6 restricted-XIP policy'
