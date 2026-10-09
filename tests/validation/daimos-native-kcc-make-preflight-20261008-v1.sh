#!/bin/sh
# Check boot-staged KCC make graphs without executing a native compiler build.
set -eu
: "${DAIMOS_REPO:?}"
: "${PDP10_PREFIX:?}"
: "${TMPDIR:?}"
work=$(mktemp -d "$TMPDIR/daimos-native-kcc-make-preflight-20261008-v1.XXXXXX")
trap 'if [ "${KEEP_WORK:-0}" = 1 ]; then echo "retained: $work"; else rm -rf "$work"; fi' EXIT HUP INT TERM

"${HOST_CC:-cc}" -std=c99 -O2 -Wall -Wextra -o "$work/pty" \
    "$(dirname "$0")/../../tools/pty-run-v1.c"
cat > "$work/probes" <<'EOF_PROBES'
probe kcc-native-default-target
command MAKE -Q -C /OPTION/SOURCE/KCC; ECHO STATUS:$?
contains STATUS:1
not_contains CANNOT PARSE
timeout 240
end
probe kcc-native-all-single-graph
command MAKE -Q -C /OPTION/SOURCE/KCC ALL; ECHO STATUS:$?
contains STATUS:1
not_contains CANNOT PARSE
timeout 240
end
probe kcc-native-clean
command MAKE -C /OPTION/SOURCE/KCC CLEAN; ECHO STATUS:$?
contains STATUS:0
timeout 120
end
probe kcc-native-first-object
command MAKE -C /OPTION/SOURCE/KCC B/CC-CPP-V1.S; ECHO STATUS:$?
contains MAKE: BUILD
contains STATUS:0
timeout 120
end
EOF_PROBES

make -C "$DAIMOS_REPO/system/boot/pdp6" image \
    PDP10_PREFIX="$PDP10_PREFIX" BUILD="$work/boot" \
    KCC_REPO="${KCC_REPO:-$HOME/git/kcc}" \
    DAS_REPO="${DAS_REPO:-$HOME/git/das}" \
    DAIMOS_TOOLS_REPO="${DAIMOS_TOOLS_REPO:-$HOME/git/daimos-tools}" \
    > "$work/build.log" 2>&1 || {
    tail -60 "$work/build.log" >&2
    exit 1
}

"$(dirname "$0")/../../tools/daimos-simh-harness-v4.sh" \
    --daimos-repo "$DAIMOS_REPO" --dofile "$work/boot/boot.ini" \
    --pty-run "$work/pty" --login ROOT --probes "$work/probes" \
    --work-dir "$work/run" --markdown-report "$work/report.md"
echo 'daimos-native-kcc-make-preflight-20261008-v1: PASS'
