#!/bin/sh
# Full standard distribution grouped-codec boot and native RUN regression.
# All artifacts are staged below TMPDIR; nothing is installed in DAIMOS.
set -eu
: "${DAIMOS_REPO:?set DAIMOS_REPO to staged DAIMOS source}"
TMPDIR=${TMPDIR:-$HOME/tmp}
PDP10_PREFIX=${PDP10_PREFIX:-$HOME/cross}
export TMPDIR PDP10_PREFIX
PATH="$PDP10_PREFIX/bin:$PATH"
export PATH
testkit=$(CDPATH= cd -- "$(dirname "$0")/../../.." && pwd -P)
repo=$(CDPATH= cd -- "$DAIMOS_REPO" && pwd -P)
here="$testkit/tests/validation/d6codec-fulldist-v1371"
work="$TMPDIR/d6codec-fulldist-v1371"
mkdir -p "$work"

printf '%s\n' 'V1371 PHASE 1: reproduce v1370 full grouped KCORE cold-boot acceptance'
if ! DAIMOS_REPO="$repo" sh \
    "$testkit/tests/validation/d6codec-fullboot-v1370/run-v1370.sh" \
    > "$work/prerequisite-v1370.log" 2>&1; then
    tail -65 "$work/prerequisite-v1370.log" >&2
    exit 1
fi
tail -7 "$work/prerequisite-v1370.log"

printf '%s\n' 'V1371 PHASE 2: stage the actual Makefile full-distribution dependencies'
# The auxiliary Makefile is parsed AFTER the production Makefile. A
# command-line --eval rule is too early to expand its file variables.
cat > "$work/stage-full-v1371.mk" <<'EOF'
stage-full-v1371: $(KCC_SOURCE_STAMP) $(SYSTEM_MANUALS) $(ASMUTILS_SOURCE_S6REC) $(DAS_NATIVE_DRIVER) $(DAS_NATIVE_PHASE1) $(DAS_NATIVE_PHASE2) $(SYSTEM_CONFIG_S6REC)
EOF
if ! make -C "$repo/system/boot/pdp6" \
    -f Makefile -f "$work/stage-full-v1371.mk" \
    BUILD="$work/normal-build" \
    USERLAND_BUILD_ROOT="$TMPDIR/d6codec-fullboot-v1370/userland-build" \
    KCC_REPO="$HOME/git/kcc" DAS_REPO="$HOME/git/das" \
    PDP10_PREFIX="$PDP10_PREFIX" \
    stage-full-v1371 > "$work/stage-full-v1371.log" 2>&1; then
    tail -65 "$work/stage-full-v1371.log" >&2
    exit 1
fi
echo 'V1371_STAGE_NATIVE_SOURCE_MANUAL_CONFIG_PASS'

printf '%s\n' 'V1371 PHASE 3: convert every legacy DXR input and build the normal D6FS root'
if ! python3 -B "$here/build_full_root_v1371.py" \
    "$repo" "$testkit" "$work" > "$work/full-root-build-v1371.log" 2>&1; then
    tail -65 "$work/full-root-build-v1371.log" >&2
    exit 1
fi
grep -E '^V1371_(INVENTORY|ROOT)_PASS' "$work/full-root-build-v1371.log"

printf '%s\n' 'V1371 PHASE 4: native grouped full-distribution LOGIN, DSH and commands'
timeout -k 2s 180s sh "$here/run_boot_v1371.sh"
echo 'PASS v1371 full standard distribution grouped D6CODEC PDP-6 cold boot'
