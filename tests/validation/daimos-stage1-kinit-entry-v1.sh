#!/bin/sh
set -eu

: "${PDP10_PREFIX:?PDP10_PREFIX must be set}"
: "${DAIMOS_REPO:?DAIMOS_REPO must be set}"
: "${TMPDIR:?TMPDIR must be set}"

make_cmd=${MAKE:-make}
tag=daimos-stage1-kinit-entry-v1
work="$TMPDIR/$tag-$$"
build="$work/build"
ini="$work/boot-entry.ini"
out="$work/simh.out"

cleanup()
{
        rm -rf "$work"
}
trap cleanup EXIT HUP INT TERM

mkdir -p "$work"
PATH="$PDP10_PREFIX/bin:$PATH" \
    "$make_cmd" -C "$DAIMOS_REPO/system/boot/pdp6" image \
    BUILD="$build" PDP10_PREFIX="$PDP10_PREFIX" >/dev/null

header=`sed -n '2p' "$build/kinit.words"`
case "$header" in
????????????) ;;
*)
        echo "$tag: malformed KINIT header: $header" >&2
        exit 1
        ;;
esac
entry_rel=`printf '%s\n' "$header" | cut -c 7-12`
entry=`printf '%o' $((030000 + 0$entry_rel))`

sed '/^go 020$/,$d' "$build/boot.ini" >"$ini"
cat >>"$ini" <<EOF_INI
break $entry
go 020
ex pc
exit
EOF_INI

set +e
timeout -k 1s 8s "$PDP10_PREFIX/bin/pdp6" "$ini" </dev/null >"$out" 2>&1
rc=$?
set -e
if [ "$rc" -ne 0 ]; then
        cat "$out" >&2
        echo "$tag: Stage1 did not reach KINIT entry $entry (SIMH $rc)" >&2
        exit 1
fi

if ! grep -F "Breakpoint, PC: 0$entry" "$out" >/dev/null 2>&1; then
        cat "$out" >&2
        echo "$tag: KINIT entry breakpoint $entry missing" >&2
        exit 1
fi

printf '%s\n' "$tag: PASS (Stage1 reaches loaded KINIT entry $entry)"
