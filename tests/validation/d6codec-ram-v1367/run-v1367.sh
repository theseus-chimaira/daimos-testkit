#!/bin/sh
# Isolated PDP-6 grouped decoder RAM/size optimization regression.
# Reuse independently host-generated current DXR goldens, never touch
# production DAIMOS code or testkit's preceding versioned fixtures.
set -eu
: "${DAIMOS_REPO:?}"
PDP10_PREFIX=${PDP10_PREFIX:-$HOME/cross}
TMPDIR=${TMPDIR:-$HOME/tmp}
export PDP10_PREFIX TMPDIR
testkit=$(CDPATH= cd -- "$(dirname "$0")/../../.." && pwd -P)
work="$TMPDIR/d6codec-ram-v1367"
mkdir -p "$work"
engine="$DAIMOS_REPO/system/kernel/core/d6codec_stream_v1367.s"
adapter="$DAIMOS_REPO/system/kernel/core/d6codec_vfs_v1367.s"

python3 -B "$testkit/tests/validation/d6codec-current-corpus-v1359/generate-v1359.py" \
  "$DAIMOS_REPO/build/system/boot/pdp6" "$work" >/dev/null
python3 -B "$testkit/tests/validation/d6codec-vfs-v1366/generate-v1366.py" \
  "$work/native_kcore_v1359.s" "$work/test-v1366-source.s"
sed 's/v1366/v1367/g' "$work/test-v1366-source.s" > "$work/test-v1367.s"

"$PDP10_PREFIX/bin/p10run" --machine pdp6 --mode deposit \
  --exec-mode go --start 1000 --timeout 40 \
  --workdir "$work/vfs" --name d6codec-vfs-v1367 \
  --expect __test_exit=0 \
  "$testkit/tests/validation/daimos-test-crt0-v1.s" \
  "$work/test-v1367.s" "$adapter" "$engine"

# Includes CRT's call and the fake leaf provider, not real cold-VFS nesting.
"$PDP10_PREFIX/bin/p10run" --machine pdp6 --mode deposit \
  --exec-mode go --start 1000 --timeout 40 \
  --workdir "$work/stack" --name d6codec-stack-v1367 \
  --expect __test_exit=0 --expect __v051_first_changed=0107 \
  "$testkit/tests/validation/d6codec-native-v051/crt_stack_v051.s" \
  "$work/test-v1367.s" "$adapter" "$engine"

# The v1361 pathological test exercises all 15 descriptor words,
# control/literal refill, malformed controls and address checks.
sed 's/v1361/v1367/g' \
  "$testkit/tests/validation/d6codec-native-stream-v1361/test_stream_v1361.s" \
  > "$work/stress-v1367.s"
"$PDP10_PREFIX/bin/p10run" --machine pdp6 --mode deposit \
  --exec-mode go --start 1000 --timeout 40 \
  --workdir "$work/stress" --name d6codec-stress-v1367 \
  --expect __test_exit=0 \
  "$testkit/tests/validation/daimos-test-crt0-v1.s" \
  "$work/stress-v1367.s" "$engine"

# Five independently host-compressed DXR prefixes, each split at
# three input-window widths, demonstrate continuation correctness.
for kind in kcore d6fs-mres monitorfs-mres swap-mres-v481 tape-mres; do
  for window in 1 7 64; do
    fixture="$work/native-$kind-$window-v1367.s"
    python3 -B "$testkit/tests/validation/d6codec-native-stream-v1361/generate_dxr_v1361.py" \
      "$work/native_${kind}_v1359.s" "$work/native-source-v1361.s" "$window"
    sed 's/v1361/v1367/g' "$work/native-source-v1361.s" > "$fixture"
    "$PDP10_PREFIX/bin/p10run" --machine pdp6 --mode deposit \
      --exec-mode go --start 1000 --timeout 40 \
      --workdir "$work/native-$kind-$window" \
      --name "d6codec-$kind-$window-v1367" --expect __test_exit=0 \
      "$testkit/tests/validation/daimos-test-crt0-v1.s" \
      "$fixture" "$engine"
  done
done

"$PDP10_PREFIX/bin/das" -F -C -O "$work/engine-v1367.dobj" "$engine"
"$PDP10_PREFIX/bin/das" -F -C -O "$work/adapter-v1367.dobj" "$adapter"
get_text() {
  "$PDP10_PREFIX/bin/pdp10-dec-none-objdump" -h "$1" |
    sed -n 's/^sections: text=\([0-9]*\) data=0 bss=0 .*/\1/p'
}
engine_size=$(get_text "$work/engine-v1367.dobj")
adapter_size=$(get_text "$work/adapter-v1367.dobj")
test -n "$engine_size" && test -n "$adapter_size"
test "$engine_size" -le 225 && test "$adapter_size" -le 92 || {
    echo "v1367: RAM reduction failed: engine=$engine_size adapter=$adapter_size" >&2
    exit 1
}
# The stack-canary and resident-state claim depend on these exact
# dimensions; reject a later silent storage increase even if text fits.
grep -Eq '^[[:space:]]*\.equ DS_WORDS,031$' "$engine"
grep -Eq '^[[:space:]]*\.equ D6C_STATE_V1367,031$' "$adapter"
grep -Eq '^[[:space:]]*\.equ D6C_FRAME_V1367,0103$' "$adapter"
printf 'RAM_V1367 engine=%s adapter=%s combined=%s old=97 savings_from_v1366=%s growth_over_old=%s\n' \
  "$engine_size" "$adapter_size" "$((engine_size+adapter_size))" \
  "$((333-engine_size-adapter_size))" "$((engine_size+adapter_size-97))"
echo 'PASS v1367: VFS ABI, stack canary, max descriptors and 15 native current-DXR refills'
