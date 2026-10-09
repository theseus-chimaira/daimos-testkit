#!/bin/sh
# Verify native MAKE includes a fragment into its current dependency graph.
set -eu
: "${DAIMOS_REPO:?}"
: "${PDP10_PREFIX:?}"
: "${TMPDIR:?}"

tag=daimos-native-make-include-20261009-v1
work=$(mktemp -d "$TMPDIR/$tag.XXXXXX")
trap 'if [ "${KEEP_WORK:-0}" = 1 ]; then echo "retained: $work"; else rm -rf "$work"; fi' EXIT HUP INT TERM

cat > "$work/top.txt" <<'EOF'
INCLUDE /CONFIG/MAKEINC
ALL: INCLUDED
> !/SYSTEM/EXEC/ECHO MAKE_INCLUDE_TOP_OK
EOF
cat > "$work/fragment.txt" <<'EOF'
.PHONY: INCLUDED
INCLUDED:
> !/SYSTEM/EXEC/ECHO MAKE_INCLUDE_FRAGMENT_OK
EOF
"$PDP10_PREFIX/bin/s6text" --encode "$work/top.txt" "$work/top.s6"
"$PDP10_PREFIX/bin/s6text" --encode "$work/fragment.txt" "$work/fragment.s6"
"${HOST_CC:-cc}" -std=c99 -O2 -Wall -Wextra -o "$work/pty" \
    "$(dirname "$0")/../../tools/pty-run-v1.c"
make -C "$DAIMOS_REPO/tools/host" build \
    BUILD_ROOT="$DAIMOS_REPO/build" > "$work/tools.log" 2>&1 || {
    tail -40 "$work/tools.log" >&2
    exit 1
}
cat > "$work/probes" <<'EOF'
probe native-make-fragment
command MAKE -F /CONFIG/MAKEINC INCLUDED; ECHO STATUS:$?
contains MAKE_INCLUDE_FRAGMENT_OK
contains STATUS:0
timeout 120
end
probe native-make-include
command MAKE -F /CONFIG/MAKETOP ALL; ECHO STATUS:$?
contains MAKE_INCLUDE_FRAGMENT_OK
contains MAKE_INCLUDE_TOP_OK
contains STATUS:0
timeout 120
end
EOF
make -C "$DAIMOS_REPO/system/boot/pdp6" image \
    PDP10_PREFIX="$PDP10_PREFIX" BUILD="$work/boot" \
    HOST_TOOLS="${HOST_TOOLS:-$DAIMOS_REPO/build/tools/host}" \
    KCC_BOOT_BUILD="${KCC_BOOT_BUILD:-$HOME/git/kcc/build-native}" \
    SIMH_DPY_MODE=HEADLESS \
    D6FS_EXTRA_ARGS="-f /CONFIG/MAKETOP:$work/top.s6:644:binwords -f /CONFIG/MAKEINC:$work/fragment.s6:644:binwords" \
    > "$work/build.log" 2>&1 || { tail -40 "$work/build.log" >&2; exit 1; }
"$(dirname "$0")/../../tools/daimos-simh-harness-v4.sh" \
    --daimos-repo "$DAIMOS_REPO" --dofile "$work/boot/boot.ini" \
    --pty-run "$work/pty" --login ROOT --probes "$work/probes" \
    --work-dir "$work/run" --markdown-report "$work/report.md"
echo "$tag: PASS"
