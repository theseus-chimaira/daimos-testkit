#!/bin/sh
set -eu

: "${PDP10_PREFIX:?PDP10_PREFIX must be set}"
: "${DAIMOS_REPO:?DAIMOS_REPO must be set}"
: "${TMPDIR:?TMPDIR must be set}"
: "${PTY_RUN:?PTY_RUN must be set}"
: "${TCP_RUN:?TCP_RUN must be set}"

TESTKIT_ROOT=${TESTKIT_ROOT:-$(CDPATH= cd -- "$(dirname "$0")/../.." && pwd)}
HARNESS=$TESTKIT_ROOT/tools/daimos-simh-harness-v4.sh
BOOT_DIR=$DAIMOS_REPO/system/boot/pdp6
WORK=$TMPDIR/daimos-boot-root-cross-matrix-v1-$$
INITTAB=$WORK/inittab-dcs0
PROBES=$WORK/probes

cleanup()
{
        rm -rf "$WORK"
}
trap cleanup 0 1 2 3 15
mkdir -p "$WORK"

# The DSK row is permanently covered by daimos-root-class-matrix-v1.  This
# test exercises every remaining supported independent boot/root pair.
printf '%s\n' '1:RESPAWN:/SYSTEM/EXEC/LOGIN' > "$INITTAB"
cat > "$PROBES" <<'EOF'
probe cross-root-login
command ECHO CROSSROOTOK
contains CROSSROOTOK
end
EOF

case_no=0
for boot in drm dtc mtc ptr; do
        for root in disk drum tape; do
                case_no=$((case_no + 1))
                build=$WORK/build-$boot-$root
                dcs_port=$((25000 + ($$ % 500) * 32 + case_no))
                ge_port=$((dcs_port + 16000))

                PATH="$PDP10_PREFIX/bin:$PATH" make -C "$BOOT_DIR" image \
                    BUILD="$build" PDP10_PREFIX="$PDP10_PREFIX" \
                    BOOT="$boot" ROOT="$root" SYSTEM_INITTAB_TEXT="$INITTAB" \
                    SIMH_DCS0_PORT="$dcs_port" SIMH_GE0_PORT="$ge_port" >/dev/null

                PDP10_PREFIX="$PDP10_PREFIX" TMPDIR="$TMPDIR" \
                    "$HARNESS" --daimos-repo "$DAIMOS_REPO" \
                    --dofile "$build/boot.ini" --pty-run "$PTY_RUN" \
                    --tcp-run "$TCP_RUN" --dcs-port "$dcs_port" \
                    --boot-timeout 300 --login ROOT --probes "$PROBES" \
                    --work-dir "$WORK/run-$boot-$root" \
                    --markdown-report "$WORK/$boot-$root.md" >/dev/null
                printf '%s\n' "boot-root-$boot-$root: PASS"
        done
done

printf '%s\n' 'boot-root-cross-matrix: PASS (12 independent combinations)'
