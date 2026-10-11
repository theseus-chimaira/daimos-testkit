#!/bin/sh
# Validate serial job flags, suffix filtering, and touch on a native PDP-6.
set -eu
: "${DAIMOS_REPO:?}"
: "${PDP10_PREFIX:?}"
export TMPDIR="${TMPDIR:-$HOME/tmp}"
export MKBOOTBANNER="${MKBOOTBANNER:-$PDP10_PREFIX/bin/mkbootbanner}"
export P10FOLD="${P10FOLD:-$PDP10_PREFIX/bin/p10fold}"
make -C "$DAIMOS_REPO/tools/host" build \
    BUILD_ROOT="$DAIMOS_REPO/build" >/dev/null
export PATH="$DAIMOS_REPO/build/tools/host:$PATH"
mkdir -p "$TMPDIR"
work=$(mktemp -d "$TMPDIR/daimos-native-make-common-simh-20261011-v1.XXXXXX")
trap 'if [ "${KEEP_WORK:-0}" = 1 ]; then echo "retained: $work"; else rm -rf "$work"; fi' EXIT HUP INT TERM
cat > "$work/yes.txt" <<'EOF'
.SUFFIXES: .C .O
.C.O:
> !/SYSTEM/EXEC/ECHO SUFFIX_RECIPE_OK
.PHONY: ALL
ALL: /CONFIG/MKSRC.O
EOF
cat > "$work/no.txt" <<'EOF'
.SUFFIXES: .C .O
.SUFFIXES:
.C.O:
> !/SYSTEM/EXEC/ECHO SUFFIX_MUST_NOT_RUN
ALL: /CONFIG/MKSRC.O
EOF
cat > "$work/options.txt" <<'EOF'
.PHONY: ALL
ALL:
> !/SYSTEM/EXEC/ECHO SERIAL_RECIPE_OK
EOF
cat > "$work/touch.txt" <<'EOF'
/TEMP/MAKETOUCH:
> !/SYSTEM/EXEC/ECHO TOUCH_RECIPE_MUST_NOT_RUN
EOF
printf '000000000001\n' > "$work/data.words"
for x in yes no options touch; do
    "$PDP10_PREFIX/bin/s6text" --encode "$work/$x.txt" "$work/$x.s6"
done
"${HOST_CC:-cc}" -std=c99 -O2 -Wall -Wextra -o "$work/pty" \
    "$(dirname "$0")/../../tools/pty-run-v1.c"
cat > "$work/probes" <<'EOF'
probe make-j-dummy
command MAKE -F /CONFIG/MKOPTS -J 4 ALL; ECHO STATUS:$?
contains SERIAL_RECIPE_OK
contains STATUS:0
end
probe make-J-dummy
command MAKE -F /CONFIG/MKOPTS -J8 ALL; ECHO STATUS:$?
contains SERIAL_RECIPE_OK
contains STATUS:0
end
probe make-suffix-active
command MAKE -F /CONFIG/MKYES -N /CONFIG/MKSRC.O; ECHO STATUS:$?
contains SUFFIX_RECIPE_OK
contains STATUS:0
end
probe make-suffix-cleared
command MAKE -F /CONFIG/MKNO -N /CONFIG/MKSRC.O; ECHO STATUS:$?
contains STATUS:1
not_contains SUFFIX_MUST_NOT_RUN
end
probe make-no-implicit
command MAKE -F /CONFIG/MKYES -R -N /CONFIG/MKSRC.O; ECHO STATUS:$?
contains STATUS:1
not_contains SUFFIX_RECIPE_OK
end
probe make-touch
command MAKE -F /CONFIG/MKTOUCH -T /TEMP/MAKETOUCH; ECHO STATUS:$?
contains STATUS:0
not_contains TOUCH_RECIPE_MUST_NOT_RUN
end
probe make-touch-stat
command STAT /TEMP/MAKETOUCH; ECHO STATUS:$?
contains STATUS:0
end
EOF
make -C "$DAIMOS_REPO/system/boot/pdp6" image \
    PDP10_PREFIX="$PDP10_PREFIX" BUILD="$work/boot" \
    MKD6FS="$DAIMOS_REPO/build/tools/host/mkd6fs" \
    PDP10_KCC="${PDP10_KCC:-$HOME/git/kcc/build/kcc}" \
    KCC="${PDP10_KCC:-$HOME/git/kcc/build/kcc}" \
    HOST_TOOLS="${HOST_TOOLS:-$DAIMOS_REPO/build/tools/host}" \
    KCC_BOOT_BUILD="${KCC_BOOT_BUILD:-$PDP10_PREFIX/lib/kcc/bootstrap}" \
    SIMH_DPY_MODE=HEADLESS \
    D6FS_EXTRA_ARGS="-f /CONFIG/MKYES:$work/yes.s6:644:binwords -f /CONFIG/MKNO:$work/no.s6:644:binwords -f /CONFIG/MKOPTS:$work/options.s6:644:binwords -f /CONFIG/MKTOUCH:$work/touch.s6:644:binwords -f /CONFIG/MKSRC.C:$work/data.words:644:words" \
    > "$work/build.log" 2>&1 || { tail -60 "$work/build.log" >&2; exit 1; }
"$(dirname "$0")/../../tools/daimos-simh-harness-v4.sh" \
    --daimos-repo "$DAIMOS_REPO" --dofile "$work/boot/boot.ini" \
    --pty-run "$work/pty" --login ROOT --probes "$work/probes" \
    --work-dir "$work/run" --markdown-report "$work/report.md"
echo 'daimos-native-make-common-simh-20261011-v1: PASS'
