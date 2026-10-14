#!/bin/sh
set -eu
: "${DAIMOS_REPO:?}"
: "${TESTKIT_REPO:?}"
PDP10_PREFIX=${PDP10_PREFIX:-/usr/local}
TMPDIR=${TMPDIR:-$HOME/tmp}
export PDP10_PREFIX TMPDIR
mkdir -p "$TMPDIR/d6codec-kcore-reloc-v088-test"
cat "$TESTKIT_REPO/tests/validation/d6codec-kcore-reloc-v088/test-v088.s" \
 "$DAIMOS_REPO/system/kernel/core/d6codec_inline_fixed_v088.s" \
 "$DAIMOS_REPO/system/kernel/core/d6codec_inline_encode_v078.s" \
 "$DAIMOS_REPO/system/kernel/core/d6codec_kpack_inline_v078.s" \
 > "$TMPDIR/d6codec-kcore-reloc-v088-test/combined-v088.s"
cat > "$TMPDIR/d6codec-kcore-reloc-v088-test/stub-v088.s" <<'ASM'
.text
.globl vfs_read_words
vfs_read_words:
        seto 1,
        popj 17,
ASM
"$PDP10_PREFIX/bin/p10run" --machine pdp6 --mode deposit --exec-mode go \
 --start 1000 --timeout 30 --workdir "$TMPDIR/d6codec-kcore-reloc-v088-test/run" \
 --name d6codec-kcore-reloc-v088 --expect __test_exit=0 \
 "$TESTKIT_REPO/tests/validation/d6codec-native-v051/crt_stack_v051.s" \
 "$TMPDIR/d6codec-kcore-reloc-v088-test/combined-v088.s" \
 "$DAIMOS_REPO/system/kernel/core/d6codec_inline_vfs_v070.s" \
 "$TMPDIR/d6codec-kcore-reloc-v088-test/stub-v088.s"
