#!/bin/sh
# Native PDP-6 KPARSE must not confuse a PC-change flag with arithmetic
# overflow while folding ordinary integer constant expressions.
set -eu

: "${DAIMOS_REPO:?DAIMOS_REPO must be set}"
: "${PDP10_PREFIX:?PDP10_PREFIX must be set}"
: "${TMPDIR:?TMPDIR must be set}"

# The project checker uses wide FCB-owner indices. An older installed
# d6fsck truncates indices >= 254, reporting the final staged file as leaked.
host_tools=${HOST_TOOLS:-$DAIMOS_REPO/build/tools/host}
if [ ! -x "$host_tools/d6fsck" ]; then
        make -C "$DAIMOS_REPO/tools/host" build PDP10_PREFIX="$PDP10_PREFIX" \
                > /dev/null
fi

tag=daimos-native-kcc-overflow-flags-20261009-v1
work=$(mktemp -d "$TMPDIR/$tag.XXXXXX")
trap 'if [ "${KEEP_WORK:-0}" = 1 ]; then echo "retained: $work"; else rm -rf "$work"; fi' EXIT HUP INT TERM

cat > "$work/flagtest.c" <<'C_SOURCE'
/* Exercise array bounds and constant arithmetic from the self-hosting case. */
#define IDENTSIZE 32
typedef unsigned long KINT;
#define IDENTWDS ((IDENTSIZE + sizeof(KINT) - 1) / sizeof(KINT))
#define R_MAXREG 014
#define R_MAX_NOPRESERVE 07
static KINT names[IDENTWDS];
static int registers[R_MAXREG - R_MAX_NOPRESERVE];
static int shifts[(1U << 4) + (1U << 2) - 18U];
int main(void)
{
    names[0] = (KINT)IDENTWDS;
    registers[0] = (int)(sizeof(shifts) / sizeof(shifts[0]));
    return (int)names[0] + registers[0];
}
C_SOURCE

"$PDP10_PREFIX/bin/csix" -e "$work/flagtest.c" "$work/flagtest.s6"
"${HOST_CC:-cc}" -std=c99 -O2 -Wall -Wextra -Werror -o "$work/pty" \
        "$(dirname "$0")/../../tools/pty-run-v1.c"

cat > "$work/probes" <<'PROBES'
probe native-kcc-int-overflow-flags
command /OPTION/BASE/EXEC/KCC -S -O /TEMP/OVFLAG.S -PGNU99 -X=PDP6 -M=GAS /CONFIG/OVFLAG.C; ECHO STATUS:$?
contains STATUS:0
not_contains constant expression overflow
not_contains KCC - 1 error
timeout 120
end
probe native-kcc-int-overflow-file
command LS /TEMP/OVFLAG.S
contains OVFLAG.S
end
PROBES

PATH="$PDP10_PREFIX/bin:$PATH" make -C "$DAIMOS_REPO/system/boot/pdp6" image \
        BUILD="$work/boot" PDP10_PREFIX="$PDP10_PREFIX" \
        HOST_TOOLS="$host_tools" \
        SIMH_CPU_KWORDS="${SIMH_CPU_KWORDS:-256}" \
        SIMH_DCS0_PORT=$((23000 + ($$ % 7000))) \
        SIMH_GE0_PORT=$((43000 + ($$ % 7000))) \
        D6FS_EXTRA_ARGS="-f /CONFIG/OVFLAG.C:$work/flagtest.s6:644:binwords" \
        > "$work/build.log" 2>&1 || {
            tail -40 "$work/build.log" >&2
            exit 1
        }

"$(dirname "$0")/../../tools/daimos-simh-harness-v4.sh" \
        --daimos-repo "$DAIMOS_REPO" --dofile "$work/boot/boot.ini" \
        --pty-run "$work/pty" --login ROOT --probes "$work/probes" \
        --timeout 120 --boot-timeout 90 \
        --work-dir "$work/run" --markdown-report "$work/report.md"

echo "$tag: PASS (native integer constant folds without false overflow)"
