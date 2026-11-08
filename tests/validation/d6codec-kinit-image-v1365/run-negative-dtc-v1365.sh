#!/bin/sh
# Two full native Type-136 media failures; no production media is changed.
set -eu
: "${DAIMOS_REPO:?}"
PDP10_PREFIX=${PDP10_PREFIX:-$HOME/cross}
TMPDIR=${TMPDIR:-$HOME/tmp}
export PDP10_PREFIX TMPDIR
PATH="$PDP10_PREFIX/bin:$PATH"
export PATH
work="$TMPDIR/d6codec-kinit-v1365"
stream="$work/kinit-grouped-v1365.words"
stage1="$work/stage1-dtc-v1365.pt"
test -s "$stream" && test -s "$stage1"
entry_off=$(sed -n '2p' "$stream" | cut -c7-12)
entry=$(printf '%06o' "$((030000 + 0$entry_off))")

for kind in oversized-header malformed-control; do
    modified="$work/kinit-grouped-$kind-v1365.words"
    case "$kind" in
      oversized-header)
        # The 18-bit maximum decoded length cannot leave physical
        # space for compressed staging and the KINIT stack.
        {
            sed -n '1p' "$stream"
            printf '%06o%s\n' 0777777 "$entry_off"
            tail -n +3 "$stream"
        } > "$modified"
        ;;
      malformed-control)
        # Zero tokens is invalid. The first compressed word is the
        # group's control; it must be rejected before any output store.
        {
            head -n 3 "$stream"
            printf '%012o\n' 0
            tail -n +5 "$stream"
        } > "$modified"
        ;;
    esac
    media="$work/kinit-grouped-$kind-dtc-v1365.dta"
    mkdt -t dtc -p "$modified" -o "$media"
    ini="$work/boot-dtc-$kind-v1365.simh"
    out="$work/boot-dtc-$kind-v1365.out"
    cat > "$ini" <<EOF_SIMH
set cpu 256k
set ptr enabled
set dct enabled
set dtc dct=04
set dtc enabled
set dtc0 enabled
deposit 020 710600000060
deposit 021 710740000010
deposit 022 254000000021
deposit 023 710440000026
deposit 024 710740000010
deposit 025 254000000024
deposit 026 000000000000
deposit 027 254000000021
attach -q ptr $stage1
deposit ptr time 1
attach -q dtc0 $media
break $entry
go 020
ex pc
ex 030000
exit
EOF_SIMH
    if ! timeout -k 2s 90s "$PDP10_PREFIX/bin/pdp6" "$ini" \
        </dev/null > "$out" 2>&1; then
        tail -70 "$out" >&2
        echo "v1365: $kind native Stage-1 did not terminate" >&2
        exit 1
    fi
    if grep -F "Breakpoint, PC: $entry" "$out" >/dev/null || \
       ! grep -F 'HALT instruction' "$out" >/dev/null; then
        tail -70 "$out" >&2
        echo "v1365: $kind incorrectly entered KINIT or did not halt" >&2
        exit 1
    fi
    if ! grep -E '^30000:[[:space:]]+000000000000' "$out" >/dev/null; then
        tail -70 "$out" >&2
        echo "v1365: $kind wrote to KINIT before the expected refusal" >&2
        exit 1
    fi
    echo "PASS v1365: actual Type-136 $kind refused before KINIT entry"
done
