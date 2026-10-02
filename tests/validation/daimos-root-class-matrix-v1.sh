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
WORK=$TMPDIR/daimos-root-class-matrix-v1-$$
PROBES=$WORK/probes
INITTAB=$WORK/inittab-dcs0

cleanup()
{
        rm -rf "$WORK"
}
trap cleanup 0 1 2 3 15
mkdir -p "$WORK"

# Root-path acceptance needs one reliable interactive terminal, not the
# separate multi-terminal stress matrix.  Keeping only DCS0 also avoids
# pointless concurrent DECtape seeks while LOGIN is first loaded from TSFS.
printf '%s\n' '1:RESPAWN:/SYSTEM/EXEC/LOGIN' > "$INITTAB"
cat > "$PROBES" <<'EOF'
probe root-class-login
command ECHO ROOTCLASSOK
contains ROOTCLASSOK
end
EOF

case_no=0
for root in disk drum tape; do
        case_no=$((case_no + 1))
        build=$WORK/build-$root
        dcs_port=$((18000 + ($$ % 1000) * 4 + case_no))
        ge_port=$((dcs_port + 4000))

        PATH="$PDP10_PREFIX/bin:$PATH" make -C "$BOOT_DIR" image \
            BUILD="$build" PDP10_PREFIX="$PDP10_PREFIX" \
            BOOT=dsk ROOT="$root" SYSTEM_INITTAB_TEXT="$INITTAB" \
            SIMH_DCS0_PORT="$dcs_port" SIMH_GE0_PORT="$ge_port" >/dev/null

        PDP10_PREFIX="$PDP10_PREFIX" TMPDIR="$TMPDIR" \
            "$HARNESS" --daimos-repo "$DAIMOS_REPO" \
            --dofile "$build/boot.ini" --pty-run "$PTY_RUN" \
            --tcp-run "$TCP_RUN" --dcs-port "$dcs_port" \
            --boot-timeout 300 --login ROOT --probes "$PROBES" \
            --work-dir "$WORK/run-$root" \
            --markdown-report "$WORK/$root.md" >/dev/null
        printf '%s\n' "root-class-$root: PASS (DSK compressed boot -> explicit root -> login)"
done

printf '%s\n' 'root-class-matrix: PASS'
