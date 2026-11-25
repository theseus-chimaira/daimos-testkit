#!/bin/sh
# Run each distinct K07 native gate once; keep all evidence on failure.
set -eu
: "${DAIMOS_REPO:?DAIMOS source checkout required}"
PDP10_PREFIX=${PDP10_PREFIX:-$HOME/cross}
TMPDIR=${TMPDIR:-$HOME/tmp}
export PDP10_PREFIX TMPDIR DAIMOS_REPO
mkdir -p "$TMPDIR"
here=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
kit=$(CDPATH= cd -- "$here/../../.." && pwd)
work=$(mktemp -d "$TMPDIR/pure-k07-native-v1940.XXXXXX")
trap 'echo "v1940 native matrix evidence: $work"' EXIT
git -C "$DAIMOS_REPO" rev-parse HEAD > "$work/daimos.commit"
git -C "$kit" rev-parse HEAD > "$work/testkit.commit"
git -C "$DAIMOS_REPO" diff > "$work/daimos.diff"
git -C "$kit" diff > "$work/testkit.diff"
rc=0
# The D6FS discard gate includes all prior D6FS media/unmount
# native controls. Avoid rerunning those same 24 variants four times.
for group in backing-identity-v1923 provider-identity-v1924 \
    dtfs-media-v1925 drop-availability-v1926 tsfs-media-v1928 \
    mutation-lease-v1932 load-reservation-v1933 exec-handover-v1934 \
    lowmem-exec-v1935 namespace-epoch-v1936 stack-lifetime-v1937 \
    memfs-mutation-v1938 d6fs-discard-v1939; do
    if make -s -C "$kit" "test-pure-$group" >"$work/$group.log" 2>&1; then
        echo "PASS $group"
    else
        echo "FAIL $group"
        tail -30 "$work/$group.log" >&2
        rc=1
    fi
done
exit "$rc"
