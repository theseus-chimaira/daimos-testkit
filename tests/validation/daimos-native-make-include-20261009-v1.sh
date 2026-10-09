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
FRAGMENT = /CONFIG/MAKEINC
SOURCES = FIRST.C SECOND.C OTHER.H
OBJECTS = $(SOURCES:.C=.DOBJ)
INCLUDE $(FRAGMENT)
include $(FRAGMENT)
-include /CONFIG/MAKE-NOT-PRESENT
ALL: INCLUDED
> !/SYSTEM/EXEC/ECHO MAKE_INCLUDE_TOP_OK
SUBST:
> !/SYSTEM/EXEC/ECHO $(OBJECTS)
EOF
cat > "$work/fragment.txt" <<'EOF'
.PHONY: INCLUDED
INCLUDED:
> !/SYSTEM/EXEC/ECHO MAKE_INCLUDE_FRAGMENT_OK
EOF
"$PDP10_PREFIX/bin/s6text" --encode "$work/top.txt" "$work/top.s6"
"$PDP10_PREFIX/bin/s6text" --encode "$work/fragment.txt" "$work/fragment.s6"
# Exercise graph growth beyond the historical 256-rule/768-dependency caps.
# Every prerequisite is PHONY, so the test does not require extra files.
{
    echo '.PHONY: ALL'
    # Extend the variable table and string storage beyond their old
    # 64-variable and 24576-character static limits.
    i=1
    while [ "$i" -le 190 ]; do
        printf 'VAR%03d = AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA\n' "$i"
        i=$((i + 1))
    done
    i=1
    while [ "$i" -le 280 ]; do
        printf 'ALL: R%03d\n' "$i"
        i=$((i + 1))
    done
    # Distinct dependencies exceed the former 768-link cap; repeated
    # prerequisites also test that growth does not invalidate link chains.
    i=1
    while [ "$i" -le 800 ]; do
        printf 'ALL: R%03d\n' "$(((i - 1) % 280 + 1))"
        i=$((i + 1))
    done
    # More than 384 recipes, but no more than one is executed: the extra
    # recipes belong to unreachable targets and remain in the MAKE graph.
    i=1
    while [ "$i" -le 400 ]; do
        printf 'UNUSED%03d:\n> !/SYSTEM/EXEC/ECHO UNUSED%03d\n' "$i" "$i"
        i=$((i + 1))
    done
    printf 'ALL:\n> !/SYSTEM/EXEC/ECHO MAKE_BIG_GRAPH_OK\n'
    i=1
    while [ "$i" -le 280 ]; do
        printf '.PHONY: R%03d\n' "$i"
        printf 'R%03d:\n' "$i"
        i=$((i + 1))
    done
} > "$work/large.txt"
"$PDP10_PREFIX/bin/s6text" --encode "$work/large.txt" "$work/large.s6"
# Insert rules in reverse lexical order, then resolve dependencies in forward
# order. This catches sorted-index insertion errors without compiling KCC.
{
    echo '.PHONY: ALL'
    i=96
    while [ "$i" -ge 1 ]; do
        printf '.PHONY: ITEM%03d\nITEM%03d:\n' "$i" "$i"
        i=$((i - 1))
    done
    i=1
    while [ "$i" -le 96 ]; do
        printf 'ALL: ITEM%03d\n' "$i"
        i=$((i + 1))
    done
    printf 'ALL:\n> !/SYSTEM/EXEC/ECHO MAKE_SORTED_INDEX_OK\n'
} > "$work/index.txt"
"$PDP10_PREFIX/bin/s6text" --encode "$work/index.txt" "$work/index.s6"
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
probe native-make-suffix-substitution
command MAKE -F /CONFIG/MAKETOP SUBST; ECHO STATUS:$?
contains FIRST.DOBJ SECOND.DOBJ OTHER.H
contains STATUS:0
timeout 120
end
probe native-make-large-graph
command MAKE -F /CONFIG/MAKEBIG ALL; ECHO STATUS:$?
contains MAKE_BIG_GRAPH_OK
contains STATUS:0
timeout 300
end
probe native-make-index-order
command MAKE -F /CONFIG/MAKEINDEX ALL; ECHO STATUS:$?
contains MAKE_SORTED_INDEX_OK
contains STATUS:0
timeout 120
end
EOF
make -C "$DAIMOS_REPO/system/boot/pdp6" image \
    PDP10_PREFIX="$PDP10_PREFIX" BUILD="$work/boot" \
    PDP10_KCC="${PDP10_KCC:-$HOME/git/kcc/build/kcc}" \
    KCC="${PDP10_KCC:-$HOME/git/kcc/build/kcc}" \
    HOST_TOOLS="${HOST_TOOLS:-$DAIMOS_REPO/build/tools/host}" \
    KCC_BOOT_BUILD="${KCC_BOOT_BUILD:-$HOME/git/kcc/build-native}" \
    SIMH_DPY_MODE=HEADLESS \
    D6FS_EXTRA_ARGS="-f /CONFIG/MAKETOP:$work/top.s6:644:binwords -f /CONFIG/MAKEINC:$work/fragment.s6:644:binwords -f /CONFIG/MAKEBIG:$work/large.s6:644:binwords -f /CONFIG/MAKEINDEX:$work/index.s6:644:binwords" \
    > "$work/build.log" 2>&1 || { tail -40 "$work/build.log" >&2; exit 1; }
"$(dirname "$0")/../../tools/daimos-simh-harness-v4.sh" \
    --daimos-repo "$DAIMOS_REPO" --dofile "$work/boot/boot.ini" \
    --pty-run "$work/pty" --login ROOT --probes "$work/probes" \
    --work-dir "$work/run" --markdown-report "$work/report.md"
echo "$tag: PASS"
