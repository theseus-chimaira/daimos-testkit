#!/bin/sh
# Capture E13 evidence for the first explicit 256K PDP-6 release
# candidate: KCC, DSK Stage 1, D6FS root, real disk/backing media.
# Run both default-disabled and disposable requester-OOM-enabled guests.
# This is NOT yet the whole cross-simulator/media E13 signoff.
set -eu
: "${DAIMOS_REPO:?}" "${PDP10_PREFIX:?}"
export TMPDIR=${TMPDIR:-$HOME/tmp}
mkdir -p "$TMPDIR"
self=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
case "${V1283_PRODUCTION_OOM_DEFAULT:-0}" in
    0) production_oom=OFF ;;
    1) production_oom=ON ;;
    *) echo 'v1283: invalid production OOM expectation' >&2; exit 2 ;;
esac
if [ "${V1174_TEST_RESIDENCY:-0}" = 1 ]; then
    work=$(mktemp -d "$TMPDIR/daimos-oom-residency-v1174.XXXXXX")
else
    work=$(mktemp -d "$TMPDIR/daimos-e13-release-media-v1160.XXXXXX")
fi
echo "v1160: evidence directory: $work"

for mode in 0 1; do
    if [ "$mode" = 0 ]; then
        label=disabled
    else
        label=enabled
    fi
    echo "v1160: starting $label DSK/D6FS release-media guest"
    if ! V1160_RELEASE_MEDIA=1 V1160_EVIDENCE_DIR="$work/$label" \
        V1159_OOM_ENABLED="$mode" \
        sh "$self/daimos-oom-protected-v1159.sh" \
        > "$work/$label-run.log" 2>&1; then
        tail -85 "$work/$label-run.log" >&2
        echo "v1160: $label FAILED; evidence retained at $work" >&2
        exit 1
    fi
    cat "$work/$label-run.log"
    test -s "$work/$label/simh.out"
    test -s "$work/$label/media-sha256.txt"
    if [ "${V1174_TEST_RESIDENCY:-0}" = 1 ]; then
        test -s "$work/$label/residency-v1174.txt"
        test -s "$work/$label/mres-packages-v1174.txt"
    fi
done

cat > "$work/README.txt" <<EOF
E13 v1160 disk-root release-media evidence: independent disposable guests.
256K PDP-6, KCC, DSK Stage 1, ROOT=disk, D6FS and real DSK0 media.
Production requester OOM default: $production_oom (see guest profiles).
Both disposable OOM-disabled and OOM-enabled policies are recorded.
Files: full build.log, SIMH transcript with complete counters, actual
boot.ini, KCORE/user INIT maps, tool and root-media SHA256, profile.
The media itself is not copied; its SHA256 attests the built file.
Passing this single simulator/media combination does NOT close E13.
EOF
if [ "${V1174_TEST_RESIDENCY:-0}" = 1 ]; then
    cat >> "$work/README.txt" <<'EOF'
v1174: resident audit observes SYS_MEMINFO in userland and an independent
SIMH read of the KINIT-patched resident immediate, plus MM capacity and
KCORE boundaries. Includes linked MRES package metadata. This is an
instrumented OOM guest, not an uninstrumented production size signoff.
EOF
fi

archive="$work.tar.gz"
tar -czf "$archive" -C "$work" .
sha256sum "$archive" > "$archive.sha256"
tar -tzf "$archive" >/dev/null
echo "v1160: enabled/disabled DSK/D6FS evidence PASS"
echo "v1160: archive=$archive"
cat "$archive.sha256"
