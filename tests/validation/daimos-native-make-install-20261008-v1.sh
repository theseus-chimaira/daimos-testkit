#!/bin/sh
# Native MAKE update-query and INSTALL word-copy/permission smoke test.
set -eu

: "${DAIMOS_REPO:?}"
: "${PDP10_PREFIX:?}"
: "${TMPDIR:?}"

work=$(mktemp -d "$TMPDIR/daimos-native-make-install-20261008-v1.XXXXXX")
trap 'if [ "${KEEP_WORK:-0}" = 1 ]; then echo "retained: $work"; else rm -rf "$work"; fi' EXIT HUP INT TERM

printf '000000000001\n' > "$work/data.words"
"${HOST_CC:-cc}" -std=c99 -O2 -Wall -Wextra -o "$work/pty" \
        "$(dirname "$0")/../../tools/pty-run-v1.c"

cat > "$work/probes" <<'EOF'
probe install-directory
command INSTALL -D -M 0755 /TEMP/TESTINSTALL; ECHO STATUS:$?
contains STATUS:0
end
probe install-copy
command INSTALL -M 0555 /CONFIG/INSTALLTEST /TEMP/TESTINSTALL/COPY; ECHO STATUS:$?
contains STATUS:0
end
probe install-content
command CMP /CONFIG/INSTALLTEST /TEMP/TESTINSTALL/COPY; ECHO STATUS:$?
contains STATUS:0
end
probe make-query-existing
command MAKE -Q -C /OPTION/SOURCE/KCC CCVLA.C; ECHO STATUS:$?
contains STATUS:0
end
probe make-query-unbuilt
command MAKE -Q -C /OPTION/SOURCE/KCC CCVLA.S; ECHO STATUS:$?
contains STATUS:1
end
EOF

make -C "$DAIMOS_REPO/system/boot/pdp6" image \
        PDP10_PREFIX="$PDP10_PREFIX" BUILD="$work/boot" \
        KCC_REPO="${KCC_REPO:-$HOME/git/kcc}" \
        DAS_REPO="${DAS_REPO:-$HOME/git/das}" \
        DAIMOS_TOOLS_REPO="${DAIMOS_TOOLS_REPO:-$HOME/git/daimos-tools}" \
        D6FS_EXTRA_ARGS="-f /CONFIG/INSTALLTEST:$work/data.words:644:words" \
        > "$work/build.log" 2>&1 || {
        tail -60 "$work/build.log" >&2
        exit 1
}

"$(dirname "$0")/../../tools/daimos-simh-harness-v4.sh" \
        --daimos-repo "$DAIMOS_REPO" --dofile "$work/boot/boot.ini" \
        --pty-run "$work/pty" --login ROOT --probes "$work/probes" \
        --work-dir "$work/run" --markdown-report "$work/report.md"
echo 'daimos-native-make-install-20261008-v1: PASS'
