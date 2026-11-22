#!/bin/sh
# Default-OFF v1804 merge: physical PDP-6 DSK/D6FS INIT smoke test.
# This is not RAW PURE pressure/reclaim acceptance.
set -eu
: "${DAIMOS_REPO:?set DAIMOS_REPO to the isolated integration checkout}"
PDP10_PREFIX=${PDP10_PREFIX:-$HOME/cross}
TMPDIR=${TMPDIR:-$HOME/tmp}
export PDP10_PREFIX TMPDIR
boot=${DAIMOS_BOOT_BUILD_V1805:-$TMPDIR/daimos-integration-v1804-build/system/boot/pdp6}
testkit=$(CDPATH= cd -- "$(dirname "$0")/../../.." && pwd)
test -s "$boot/boot.ini"
test -s "$boot/kcore.map"
test -x "$PDP10_PREFIX/bin/pdp6"
mkdir -p "$TMPDIR"
work=$(mktemp -d "$TMPDIR/daimos-v1805-smoke.XXXXXX")
# The guest writes D6FS/logstore and backing media. Never attach the
# build's source disks directly: a second boot would inherit mutations.
mkdir -p "$work/disk" "$work/drum"
for media in "$boot"/disk/dsk*.dsk; do
    test -s "$media"
    cp --sparse=always "$media" "$work/disk/"
done
for media in "$boot"/drum/dsk*.dsk; do
    test -s "$media"
    cp --sparse=always "$media" "$work/drum/"
done
port=$((35000 + ($$ % 10000)))
sh "$testkit/tests/lib/daimos-simh-headless.sh" \
    "$boot/boot.ini" "$work/boot.ini" "$port" "$((port + 12000))"
sed -e "s|$boot/disk/|$work/disk/|g" \
    -e "s|$boot/drum/|$work/drum/|g" \
    "$work/boot.ini" >"$work/boot-isolated.ini"
mv "$work/boot-isolated.ini" "$work/boot.ini"
set +e
(
    cd "$boot"
    TERM=dumb timeout -k 3s "${DAIMOS_SMOKE_SECONDS_V1805:-45}" \
        stdbuf -o0 -e0 "$PDP10_PREFIX/bin/pdp6" "$work/boot.ini"
) >"$work/console.log" 2>&1
rc=$?
set -e
tr -d '\r' <"$work/console.log" >"$work/console.clean"
if test "$rc" -ne 124; then
    tail -45 "$work/console.clean" >&2
    echo "FAIL v1805: guest exited early (rc=$rc); evidence $work" >&2
    exit 1
fi
for marker in 'MEM                                 256 K' \
              'DSK270                                OK' \
              'DRM236                                OK' \
              'D6FS                              LOADED' \
              'INIT V1' 'LOGIN:'; do
    if ! grep -F "$marker" "$work/console.clean" >/dev/null; then
        tail -45 "$work/console.clean" >&2
        echo "FAIL v1805: missing guest witness: $marker; evidence $work" >&2
        exit 1
    fi
done
if grep -E '(^HALT|\?RT|INIT: (RUN|RESPAWN) FAILED)' "$work/console.clean" >/dev/null; then
    tail -45 "$work/console.clean" >&2
    echo "FAIL v1805: boot failure; evidence $work" >&2
    exit 1
fi
echo "PASS v1805: 256K PDP-6 disk-root physical INIT/login smoke; evidence $work"
