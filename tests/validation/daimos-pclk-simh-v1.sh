#!/bin/sh
set -eu

: "${TMPDIR:?TMPDIR must be set}"
simh=${SIMH_PDP6:-${PDP10_PREFIX:+$PDP10_PREFIX/bin/pdp6}}
if [ -z "$simh" ]; then
        echo 'daimos-pclk-simh-v1: SIMH_PDP6 or PDP10_PREFIX must select pdp6' >&2
        exit 2
fi

tag=daimos-pclk-simh-v1
work="$TMPDIR/$tag-$$"
trap 'rm -rf "$work"' EXIT HUP INT TERM
mkdir -p "$work"

run_mode()
{
        mode=$1
        want=$2
        ini="$work/$mode.ini"
        out="$work/$mode.out"
        cat >"$ini" <<EOF_MODE
set pclk enabled
set pclk $mode
show pclk
exit
EOF_MODE
        TERM=dumb "$simh" "$ini" >"$out" 2>&1
        tr -d '\r' <"$out" | grep -F 'PCLK    on' >/dev/null || {
                cat "$out" >&2
                echo "$tag: PCLK did not enable in $mode mode" >&2
                exit 1
        }
        tr -d '\r' <"$out" | grep -F "$want" >/dev/null || {
                cat "$out" >&2
                echo "$tag: PCLK $mode mode not reported" >&2
                exit 1
        }
}

run_mode REALTIME realtime
run_mode HISTORICAL historical
printf '%s\n' "$tag: PASS (PDP-6 PCLK REALTIME and HISTORICAL modes)"
