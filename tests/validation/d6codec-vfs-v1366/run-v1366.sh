#!/bin/sh
set -eu
: "${DAIMOS_REPO:?}"
PDP10_PREFIX=${PDP10_PREFIX:-$HOME/cross}
TMPDIR=${TMPDIR:-$HOME/tmp}
export PDP10_PREFIX TMPDIR
testkit=$(CDPATH= cd -- "$(dirname "$0")/../../.." && pwd -P)
work="$TMPDIR/d6codec-vfs-v1366"
mkdir -p "$work"
python3 -B "$testkit/tests/validation/d6codec-current-corpus-v1359/generate-v1359.py" \
  "$DAIMOS_REPO/build/system/boot/pdp6" "$work" >/dev/null
python3 -B "$testkit/tests/validation/d6codec-vfs-v1366/generate-v1366.py" \
  "$work/native_kcore_v1359.s" "$work/test_vfs_v1366.s"
"$PDP10_PREFIX/bin/p10run" --machine pdp6 --mode deposit \
  --exec-mode go --start 1000 --timeout 40 \
  --workdir "$work/native" --name d6codec-vfs-v1366 --expect __test_exit=0 \
  "$testkit/tests/validation/daimos-test-crt0-v1.s" \
  "$work/test_vfs_v1366.s" \
  "$DAIMOS_REPO/system/kernel/core/d6codec_vfs_v1366.s" \
  "$DAIMOS_REPO/system/kernel/core/d6codec_stream_v1366.s"

# The canary includes the CRT's main call, the 68-word frame, the
# decoder entry and its nested compressed-word fetch subroutine.
# The fake VFS provider is a leaf; this is not real cold-provider depth.
"$PDP10_PREFIX/bin/p10run" --machine pdp6 --mode deposit \
  --exec-mode go --start 1000 --timeout 40 \
  --workdir "$work/stack" --name d6codec-vfs-stack-v1366 \
  --expect __test_exit=0 --expect __v051_first_changed=0110 \
  "$testkit/tests/validation/d6codec-native-v051/crt_stack_v051.s" \
  "$work/test_vfs_v1366.s" \
  "$DAIMOS_REPO/system/kernel/core/d6codec_vfs_v1366.s" \
  "$DAIMOS_REPO/system/kernel/core/d6codec_stream_v1366.s"

"$PDP10_PREFIX/bin/das" -F -C \
    -O "$work/d6codec_vfs_v1366.dobj" \
    "$DAIMOS_REPO/system/kernel/core/d6codec_vfs_v1366.s"
"$PDP10_PREFIX/bin/das" -F -C \
    -O "$work/d6codec_stream_v1366.dobj" \
    "$DAIMOS_REPO/system/kernel/core/d6codec_stream_v1366.s"
adapter_header=$("$PDP10_PREFIX/bin/pdp10-dec-none-objdump" -h \
                 "$work/d6codec_vfs_v1366.dobj")
engine_header=$("$PDP10_PREFIX/bin/pdp10-dec-none-objdump" -h \
                "$work/d6codec_stream_v1366.dobj")
echo "NATIVE_OBJECT adapter $adapter_header"
echo "NATIVE_OBJECT engine $engine_header"
adapter_size=$(printf '%s\n' "$adapter_header" | sed -n 's/^sections: text=\([0-9]*\) .*/\1/p')
engine_size=$(printf '%s\n' "$engine_header" | sed -n 's/^sections: text=\([0-9]*\) .*/\1/p')
test -n "$adapter_size" && test -n "$engine_size"
test "$adapter_size" -le 96 && test "$engine_size" -le 237 || {
  echo 'v1366: staged resident text exceeds measured limits' >&2
  exit 1
}
for h in "$adapter_header" "$engine_header"; do
  case "$h" in
    *'data=0 bss=0 '*) ;;
    *) echo 'v1366: unexpected permanent data/BSS' >&2; exit 1 ;;
  esac
done
echo "STAGED_RAM_COST_V1366 grouped_text=$((adapter_size + engine_size)) legacy_text=97 extra_words=$((adapter_size + engine_size - 97))"
echo 'PASS v1366 grouped VFS adapter, trusted/exact buffers, stack canary and text budget'
