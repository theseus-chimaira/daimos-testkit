#!/bin/sh
# Prepare and execute a bounded native KCC source rebuild under SIMH.
# Invoked explicitly by the operator's make target; never runs on preparation.
set -eu
: "${DAIMOS_REPO:?set DAIMOS_REPO}"
: "${PDP10_PREFIX:?set PDP10_PREFIX}"
: "${TMPDIR:=${HOME}/tmp}"
KCC_REPO=${KCC_REPO:-$HOME/git/kcc}
DAS_REPO=${DAS_REPO:-$HOME/git/das}
DAIMOS_TOOLS_REPO=${DAIMOS_TOOLS_REPO:-$HOME/git/daimos-tools}
KCC_TIMEOUT=${KCC_TIMEOUT:-900}
case $KCC_TIMEOUT in *[!0-9]*|'') echo 'KCC_TIMEOUT must be seconds' >&2; exit 2;; esac
mkdir -p "$TMPDIR"
work=$(mktemp -d "$TMPDIR/daimos-kcc-manual-rebuild-20261008-v1.XXXXXX")
root=$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd -P)
trap 'echo "Artifacts retained: '$work'"' EXIT
printf 'Run directory: %s\n' "$work"
cat > "$work/probes" <<EOF_PROBES
probe kcc-source-cc-cpp
command MAKE -C /OPTION/SOURCE/KCC B/CC-CPP-V1.S; ECHO STATUS:\$?
contains STATUS:0
timeout $KCC_TIMEOUT
end
EOF_PROBES
cc -std=c99 -O2 -Wall -Wextra -Werror -o "$work/pty" "$root/tools/pty-run-v1.c"
printf '%s\n' 'Building DAIMOS disk image and native compiler bootstrap...'
make -C "$DAIMOS_REPO/system/boot/pdp6" image \
    BUILD="$work/boot" PDP10_PREFIX="$PDP10_PREFIX" \
    KCC_REPO="$KCC_REPO" DAS_REPO="$DAS_REPO" \
    DAIMOS_TOOLS_REPO="$DAIMOS_TOOLS_REPO" \
    > "$work/build.log" 2>&1 || {
        tail -40 "$work/build.log" >&2
        exit 1
    }
printf '%s\n' 'Running real KCC CC.C source compilation through target MAKE...'
"$root/tools/daimos-simh-harness-v4.sh" \
    --daimos-repo "$DAIMOS_REPO" --dofile "$work/boot/boot.ini" \
    --pty-run "$work/pty" --login ROOT --probes "$work/probes" \
    --work-dir "$work/run" --markdown-report "$work/report.md"
printf '%s\n' 'KCC native source compile: PASS'
