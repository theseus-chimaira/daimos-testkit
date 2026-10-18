#!/bin/sh
set -eu

: "${PDP10_PREFIX:?PDP10_PREFIX must be set}"
: "${DAIMOS_REPO:?DAIMOS_REPO must be set}"
: "${AAP_PDP6_REPO:?AAP_PDP6_REPO must point to the AAP PDP-6 source tree}"
: "${TMPDIR:?TMPDIR must be set}"

tag=daimos-apr-aap-v1
work="$TMPDIR/$tag-$$"
self=$(CDPATH= cd -- "$(dirname "$0")" && pwd -P)
trap 'rm -rf "$work"' EXIT HUP INT TERM
mkdir -p "$work"

das="$PDP10_PREFIX/bin/das"
dlink="$PDP10_PREFIX/bin/dlink"
dxrconvert="$PDP10_PREFIX/bin/dxrconvert"
aap="$AAP_PDP6_REPO/emu/pdp6_headless_v1"

test -x "$aap" || make -C "$AAP_PDP6_REPO/emu" pdp6_headless_v1 >/dev/null

"$das" -C -F -O "$work/harness.dobj" "$self/daimos-apr-aap-v1.s"
"$das" -C -F -O "$work/clk.dobj" "$DAIMOS_REPO/system/kernel/drivers/clk_io.s"
"$dlink" -b 020 -o "$work/test.dxr" -M "$work/test.map" \
    "$work/harness.dobj" "$work/clk.dobj"
"$dxrconvert" --rim -b 020 "$work/test.dxr" "$work/test.rim"

result=$(awk '$1 == "__test_result" { print $2; exit }' "$work/test.map")
test -n "$result" || {
        echo "$tag: cannot locate __test_result" >&2
        exit 1
}

set +e
(
        cd "$work"
        {
                # The headless executable uses its built-in CPU/memory layout
                # instead of reading init.ini, so load the program explicitly.
                printf 'load -r %s\n' "$work/test.rim"
                printf '%s\n' 'power on'
                sleep 1
                printf '%s\n' 'start 020'
                sleep 1
                printf 'examine 0%s\n' "$result"
                printf '%s\n' quit
        } | "$aap"
) >"$work/aap.out" 2>&1
rc=$?
set -e
if [ "$rc" -ne 0 ]; then
        cat "$work/aap.out" >&2
        echo "$tag: AAP emulator failed: $rc" >&2
        exit 1
fi

# The focused proc_exit_current stub stores 1 only after the production APR
# handler has cleared the fault, dismissed PI6, and reached its exit trampoline.
grep -Eq "^[>[:space:]]*0*$result: +0*1$" "$work/aap.out" || {
        cat "$work/aap.out" >&2
        echo "$tag: production APR handler did not deliver AAP user PDL fault" >&2
        exit 1
}

printf '%s\n' "$tag: PASS (production DAIMOS APR fault path on AAP PDP-6)"
