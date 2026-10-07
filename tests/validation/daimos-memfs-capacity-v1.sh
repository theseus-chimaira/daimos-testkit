#!/bin/sh
set -eu

: "${PDP10_PREFIX:?PDP10_PREFIX must be set}"
: "${DAIMOS_REPO:?DAIMOS_REPO must be set}"
: "${TMPDIR:?TMPDIR must be set}"

tag=daimos-memfs-capacity-v1
work="$TMPDIR/$tag-$$"
build="$work/build"
pty="$work/pty-run"
probes="$work/probes.txt"
dcs_port=$((23000 + ($$ % 7000)))
ge_port=$((43000 + ($$ % 7000)))
self=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
trap 'rm -rf "$work"' EXIT HUP INT TERM
mkdir -p "$work"

export PATH="$PDP10_PREFIX/bin:$PATH"
cc_host=${HOST_CC:-cc}
"$cc_host" -std=c99 -O2 -Wall -Wextra -o "$pty" \
        "$self/../../tools/pty-run-v1.c"

cat >"$probes" <<'EOF_PROBES'
probe memfs-logical-capacity
command DF
contains MEMFS /TEMP 4096 0 4096
end
EOF_PROBES

PATH="$PDP10_PREFIX/bin:$PATH" make -C "$DAIMOS_REPO/system/boot/pdp6" image \
        BUILD="$build/system/boot/pdp6" PDP10_PREFIX="$PDP10_PREFIX" \
        DAS_REPO="${DAS_REPO:-$DAIMOS_REPO/../das}" \
        DAIMOS_TOOLS_REPO="${DAIMOS_TOOLS_REPO:-$DAIMOS_REPO/../daimos-tools}" \
        KCC_REPO="${KCC_REPO:-$DAIMOS_REPO/../kcc}" \
        SIMH_DCS0_PORT="$dcs_port" SIMH_GE0_PORT="$ge_port" >/dev/null

"$self/../../tools/daimos-simh-harness-v4.sh" \
        --daimos-repo "$DAIMOS_REPO" \
        --dofile "$build/system/boot/pdp6/boot.ini" \
        --pty-run "$pty" --login ROOT --probes "$probes" \
        --work-dir "$work/run" --markdown-report "$work/report.md"

printf '%s\n' "$tag: PASS (FSTAB MEMFS WORDS is the logical mutable-data capacity)"
