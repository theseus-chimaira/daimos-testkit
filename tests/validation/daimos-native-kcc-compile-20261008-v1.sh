#!/bin/sh
set -eu

: "${PDP10_PREFIX:?PDP10_PREFIX must be set}"
: "${DAIMOS_REPO:?DAIMOS_REPO must be set}"
: "${KCC_REPO:?KCC_REPO must be set}"
: "${DAS_REPO:?DAS_REPO must be set}"
: "${DAIMOS_TOOLS_REPO:?DAIMOS_TOOLS_REPO must be set}"
: "${TMPDIR:?TMPDIR must be set}"

tag=daimos-native-kcc-compile-20261008-v1
work="$TMPDIR/$tag-$$"
build="$work/boot"
pty="$work/pty-run"
probes="$work/probes.txt"

cleanup()
{
        if [ "${KEEP_WORK:-0}" = 1 ]; then
                printf '%s\n' "$tag: retained $work" >&2
        else
                rm -rf "$work"
        fi
}
trap cleanup EXIT HUP INT TERM
mkdir -p "$work"

printf '%s\n' 'int main(void) { return 0; }' > "$work/probe.c"
"$PDP10_PREFIX/bin/csix" -e "$work/probe.c" "$work/probe.s6"

"${HOST_CC:-cc}" -std=c99 -O2 -Wall -Wextra -o "$pty" \
        "$(dirname "$0")/../../tools/pty-run-v1.c"

cat > "$probes" <<'EOF_PROBES'
probe native-kcc-compile
command /OPTION/BASE/EXEC/KCC -S -O /SCRATCH/KCCPROBE.S /CONFIG/KCCPROBE.C; ECHO STATUS:$?
contains STATUS:0
timeout 240
end
probe native-kcc-output
command LS /SCRATCH/KCCPROBE.S
contains KCCPROBE.S
end
EOF_PROBES

PDP10_PREFIX="$PDP10_PREFIX" make -C "$DAIMOS_REPO/system/boot/pdp6" image \
        PDP10_PREFIX="$PDP10_PREFIX" BUILD="$build" \
        KCC_REPO="$KCC_REPO" DAS_REPO="$DAS_REPO" \
        DAIMOS_TOOLS_REPO="$DAIMOS_TOOLS_REPO" \
        SIMH_CPU_KWORDS=96 \
        D6FS_EXTRA_ARGS="-f /CONFIG/KCCPROBE.C:$work/probe.s6:644:binwords" \
        > "$work/build.log" 2>&1

PDP10_PREFIX="$PDP10_PREFIX" \
        "$(dirname "$0")/../../tools/daimos-simh-harness-v4.sh" \
        --daimos-repo "$DAIMOS_REPO" \
        --dofile "$build/boot.ini" --pty-run "$pty" \
        --login ROOT --probes "$probes" \
        --work-dir "$work/run" --markdown-report "$work/report.md"

printf '%s\n' "$tag: PASS (native KCPP/KPARSE/KGEN/KOPT and output)"
