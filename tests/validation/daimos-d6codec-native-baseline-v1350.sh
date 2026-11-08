#!/bin/sh
# Repeat the existing grouped-codec PDP-6 staging regressions as one
# versioned, independently auditable baseline. Does NOT enable D6CODEC.
set -eu
: "${DAIMOS_REPO:?}" "${PDP10_PREFIX:?}"
root_tmp=${TMPDIR:-$HOME/tmp}
mkdir -p "$root_tmp"
name=daimos-d6codec-native-baseline-v1350-evidence-r1
work=$(mktemp -d "$root_tmp/$name.XXXXXX")
testkit=$(CDPATH= cd -- "$(dirname "$0")/../.." && pwd -P)
mkdir -p "$work/native-run" "$work/logs"

# Each historical test owns fixed workdir names; isolate them without
# editing its fixtures or running into a concurrent source checkout.
export TMPDIR="$work/native-run"
for version in 045 047 048 049 051; do
    path="$testkit/tests/validation/d6codec-native-v$version/run-v$version.sh"
    test -f "$path"
    echo "v1350: running grouped codec native v$version"
    sh "$path" > "$work/logs/native-v$version.log" 2>&1 || {
        tail -45 "$work/logs/native-v$version.log" >&2
        exit 1
    }
    count=$(grep -c '^PASS d6codec-' "$work/logs/native-v$version.log" || :)
    test "$count" -gt 0 || {
        echo "v1350: native v$version has no successful test records" >&2
        exit 1
    }
    echo "v1350: native v$version: $count PASS"
done
echo 'v1350: running staged production-codec ABI wrapper v055'
sh "$testkit/tests/validation/d6codec-kcore-abi-v055/run-v055.sh" \
    > "$work/logs/kcore-abi-v055.log" 2>&1 || {
        tail -45 "$work/logs/kcore-abi-v055.log" >&2
        exit 1
    }
grep -q '^PASS d6codec-kcore-abi-v055 on pdp6$' \
    "$work/logs/kcore-abi-v055.log"

cat > "$work/README.txt" <<'EOF'
DAIMOS v1350 grouped D6CODEC staged native PDP-6 regression baseline.
Runs historical v045, v047, v048, v049, v051 and the actual staged
production wrapper v055 in isolated workdirs, with unmodified sources.
These tests cover golden corpora, bounds, malformed streams and ABI.
The current production D6LZ36 boot/EXEC/VFS/TSFS remains unchanged.
This is NOT approval of atomic production D6CODEC format cutover;
real boot, kernel stack peaks and format migration remain OPEN.
EOF
printf 'DAIMOS=%s\nTESTKIT=%s\n' \
    "$(git -C "$DAIMOS_REPO" rev-parse HEAD)" \
    "$(git -C "$testkit" rev-parse HEAD)" > "$work/revisions.txt"
(cd "$work" && find logs -type f -print | sort | while read -r p; do
    sha256sum "$p"
done > manifest.sha256 && sha256sum -c manifest.sha256 >/dev/null)
tar -czf "$root_tmp/$name.tar.gz" -C "$(dirname "$work")" \
    "$(basename "$work")"
echo "v1350: evidence=$root_tmp/$name.tar.gz"
sha256sum "$root_tmp/$name.tar.gz"
echo 'v1350: staged grouped codec native baseline PASS (not cutover)'
