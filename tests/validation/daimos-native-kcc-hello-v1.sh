#!/bin/sh
set -eu

: "${PDP10_PREFIX:?PDP10_PREFIX must be set}"
: "${DAIMOS_REPO:?DAIMOS_REPO must be set}"
: "${KCC_REPO:?KCC_REPO must be set}"
: "${DAS_REPO:?DAS_REPO must be set}"
: "${DAIMOS_TOOLS_REPO:?DAIMOS_TOOLS_REPO must be set}"
: "${TMPDIR:?TMPDIR must be set}"

# DAIMOS guest-native KCC compilation only; this does not link or run
# the generated program. The boot/console harness is local to this repo.
os_testkit=${DAIMOS_TESTKIT_REPO:-$(CDPATH= cd -- "$(dirname "$0")/../.." && pwd -P)}
test -f "$os_testkit/tools/daimos-simh-harness-v4.sh"

tag=daimos-native-kcc-hello-v1
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

cat > "$work/probe.c" <<'EOF_C'
/* Minimal native KCC hello-world compilation smoke test. */
extern int puts(const char *);
int main(void)
{
    return puts("Hello, world!") < 0;
}
EOF_C
"$PDP10_PREFIX/bin/csix" -e "$work/probe.c" "$work/probe.s6"

"${HOST_CC:-cc}" -std=c99 -O2 -Wall -Wextra -o "$pty" \
        "$os_testkit/tools/pty-run-v1.c"

cat > "$probes" <<'EOF_PROBES'
probe native-kcc-hello-compile
command /OPTION/BASE/EXEC/KCC -S -O /SCRATCH/KCCPROBE.S /CONFIG/KCCPROBE.C; ECHO STATUS:$?
contains STATUS:0
timeout 240
end
probe native-kcc-hello-output
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
        "$os_testkit/tools/daimos-simh-harness-v4.sh" \
        --daimos-repo "$DAIMOS_REPO" \
        --dofile "$build/boot.ini" --pty-run "$pty" \
        --login ROOT --probes "$probes" \
        --work-dir "$work/run" --markdown-report "$work/report.md"

printf '%s\n' "$tag: PASS (native Hello world compilation to assembly)"
