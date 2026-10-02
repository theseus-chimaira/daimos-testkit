#!/bin/sh
set -eu

: "${DAIMOS_REPO:?DAIMOS_REPO must be set}"
: "${PDP10_PREFIX:?PDP10_PREFIX must be set}"
: "${TMPDIR:?TMPDIR must be set}"

TESTKIT_ROOT=${TESTKIT_ROOT:-$(CDPATH= cd -- "$(dirname "$0")/../../.." && pwd)}
BUILD_ROOT=${BUILD_ROOT:-$TESTKIT_ROOT/build}
KERNEL_BUILD=${KERNEL_BUILD:-$BUILD_ROOT/tests/system/kernel}
PTY_RUN=${PTY_RUN:-$BUILD_ROOT/tools/pty-run-v1}
LOGSTORE=${LOGSTORE:-$PDP10_PREFIX/bin/logstore}
HARNESS=$TESTKIT_ROOT/tools/daimos-simh-harness-v4.sh
PROBES=$TESTKIT_ROOT/tests/system/d6fs-hdd-v2/probes-v1.txt
WORK=$TMPDIR/daimos-d6fs-hdd-v2-$$
REPORT=${D6FS_HDD_REPORT:-$TESTKIT_ROOT/reports/d6fs-hdd-v2.md}

mkdir -p "$BUILD_ROOT/tools" "$(dirname "$REPORT")" "$WORK"
if [ ! -x "$PTY_RUN" ]; then
        ${HOST_CC:-cc} -std=c99 -O2 -Wall -Wextra \
            -o "$PTY_RUN" "$TESTKIT_ROOT/tools/pty-run-v1.c"
fi

# A writable D6FS mount intentionally marks the filesystem DIRTY.  Each
# runtime test therefore starts from newly formatted media rather than reusing
# a disk left dirty by a previous simulator termination.
rm -rf "$KERNEL_BUILD/disk"
LOGSTORE_WRAPPER=$WORK/logstore-init-wrapper.sh
LOGSTORE_TRACE=$WORK/logstore-init.trace
cat > "$LOGSTORE_WRAPPER" <<'EOF'
#!/bin/sh
set -eu
: "${REAL_LOGSTORE:?REAL_LOGSTORE must be set}"
: "${LOGSTORE_TRACE:?LOGSTORE_TRACE must be set}"
printf '%s\n' "$*" >> "$LOGSTORE_TRACE"
exec "$REAL_LOGSTORE" "$@"
EOF
chmod +x "$LOGSTORE_WRAPPER"
REAL_LOGSTORE="$LOGSTORE" LOGSTORE_TRACE="$LOGSTORE_TRACE" \
make -C "$TESTKIT_ROOT/tests/system/kernel" image \
    DAIMOS_REPO="$DAIMOS_REPO" BUILD="$KERNEL_BUILD" \
    PDP10_PREFIX="$PDP10_PREFIX" TMPDIR="$TMPDIR" \
    LOGSTORE="$LOGSTORE_WRAPPER"
if ! grep -q -- '--init' "$LOGSTORE_TRACE"; then
        cat "$LOGSTORE_TRACE" >&2 || true
        echo 'd6fs-hdd-v2: production image build did not initialize LOGSTORE' >&2
        exit 1
fi

TMPDIR="$TMPDIR" PDP10_PREFIX="$PDP10_PREFIX" \
    "$HARNESS" --daimos-repo "$DAIMOS_REPO" \
    --dofile "$KERNEL_BUILD/boot.ini" \
    --pty-run "$PTY_RUN" --login ROOT --probes "$PROBES" \
    --work-dir "$WORK" --markdown-report "$REPORT"

"$LOGSTORE" -n 1 -d "$KERNEL_BUILD/disk" --dump > "$WORK/d6log.out"
if grep -q 'valid=1' "$WORK/d6log.out"; then
        cat "$WORK/d6log.out" >&2
        echo 'd6fs-hdd-v2: clean boot created a LOGSTORE record' >&2
        exit 1
fi
