#!/bin/sh
# Regression: freshly created native KCC build directory through MAKE ALL.
# A fatal event status (e.g. decimal 131073 / octal 0400001) is NOT success.
set -eu
: "${PDP10_PREFIX:?PDP10_PREFIX is required}"
: "${DAIMOS_REPO:?DAIMOS_REPO is required}"
: "${TMPDIR:=${HOME}/tmp}"
mkdir -p "$TMPDIR"
work=$(mktemp -d "$TMPDIR/daimos-kcc-make-all-fresh-20261008-v1.XXXXXX")
# Retain all artifacts on both success and failure for SIMH diagnosis.
trap 'printf "Artifacts retained: %s\n" "$work"' EXIT
repo=$(CDPATH= cd -- "$(dirname "$0")/../.." && pwd -P)
cat > "$work/probes" <<'PROBES'
probe kcc-make-all-fresh
command CD /OPTION/SOURCE/KCC; MAKE ALL; ECHO STATUS:$?
contains MAKE: BUILD B
contains STATUS:0
not_contains STATUS:131073
timeout 120
end
PROBES
${HOST_CC:-cc} -std=c99 -O2 -Wall -Wextra -Werror -o "$work/pty" \
    "$repo/tools/pty-run-v1.c"
make -C "$DAIMOS_REPO/system/boot/pdp6" image \
    PDP10_PREFIX="$PDP10_PREFIX" BUILD="$work/boot" \
    KCC_REPO="${KCC_REPO:-$HOME/git/kcc}" \
    DAS_REPO="${DAS_REPO:-$HOME/git/das}" \
    DAIMOS_TOOLS_REPO="${DAIMOS_TOOLS_REPO:-$HOME/git/daimos-tools}" \
    > "$work/build.log" 2>&1 || {
        tail -50 "$work/build.log" >&2
        exit 1
    }
"$repo/tools/daimos-simh-harness-v4.sh" \
    --daimos-repo "$DAIMOS_REPO" --dofile "$work/boot/boot.ini" \
    --pty-run "$work/pty" --login ROOT --probes "$work/probes" \
    --work-dir "$work/run" --markdown-report "$work/report.md"
printf '%s\n' 'daimos-kcc-make-all-fresh-20261008-v1: PASS'
