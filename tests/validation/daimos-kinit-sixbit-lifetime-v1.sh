#!/bin/sh
set -eu
: "${DAIMOS_REPO:?DAIMOS_REPO must be set}"
tag=daimos-kinit-sixbit-lifetime-v1
src="$DAIMOS_REPO/system/kernel/boot/kinit_io_pdp6.s"
[ -f "$src" ] || { echo "$tag: missing $src" >&2; exit 1; }
if grep -Eq 'pushj[[:space:]]+0*17,0*77760' "$src"; then
        echo "$tag: KINIT still depends on Stage1 fixed SIXBIT helper at 077760" >&2
        exit 1
fi
awk '/^kinit_put6:/{p=1} p{print} /^kinit_call18:/{exit}' "$src" > "${TMPDIR:?TMPDIR must be set}/$tag-$$.s"
frag="${TMPDIR}/$tag-$$.s"
trap 'rm -f "$frag"' EXIT HUP INT TERM
grep -Eq 'coni[[:space:]]+0*120,' "$frag" || { echo "$tag: local CTY ready polling missing" >&2; exit 1; }
grep -Eq 'datao[[:space:]]+0*120,' "$frag" || { echo "$tag: local CTY output missing" >&2; exit 1; }
grep -Eq 'sojg[[:space:]]+0*6,' "$frag" || { echo "$tag: local six-character loop missing" >&2; exit 1; }
echo "$tag: PASS (KINIT SIXBIT diagnostics are independent of Stage1 scratch core)"
