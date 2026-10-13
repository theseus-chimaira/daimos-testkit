#!/bin/sh
set -eu

: "${TMPDIR:?TMPDIR must be set}"
: "${PDP10_PREFIX:?PDP10_PREFIX must be set}"
: "${DAIMOS_REPO:?DAIMOS_REPO must be set}"
: "${DAS_ROOT:?DAS_ROOT must be set}"

tmp="$TMPDIR/compiler-dependency-invalidation-v1-$$"
prefix="$tmp/prefix"
trap 'rm -rf "$tmp"' EXIT HUP INT TERM
mkdir -p "$prefix/bin"

cp "$PDP10_PREFIX/bin/kcc" "$prefix/bin/kcc"
for f in "$PDP10_PREFIX"/bin/*; do
    b=${f##*/}
    test "$b" = kcc && continue
    ln -s "$f" "$prefix/bin/$b"
done
ln -s "$PDP10_PREFIX/include" "$prefix/include"
ln -s "$PDP10_PREFIX/lib" "$prefix/lib"

# The boot-level KCORE stamp must notice a compiler replacement and invoke
# the inner kernel build.  C-generated assembly must change timestamp while a
# copied handwritten source remains untouched.
kbuild="$tmp/boot"
mkdir -p "$kbuild"
make -C "$DAIMOS_REPO/system/boot/pdp6" \
    BUILD="$kbuild" PDP10_PREFIX="$prefix" \
    "$kbuild/.kcore-built" >/dev/null
gen_before=$(stat -c %Y "$kbuild/kcore-asm/mm.s")
hand_before=$(stat -c %Y "$kbuild/kcore-asm/ret.s")
stamp_before=$(stat -c %Y "$kbuild/.kcore-built")
sleep 1
touch "$prefix/bin/kcc"
make -C "$DAIMOS_REPO/system/boot/pdp6" \
    BUILD="$kbuild" PDP10_PREFIX="$prefix" \
    "$kbuild/.kcore-built" >"$tmp/kernel-rebuild.log" 2>&1
gen_after=$(stat -c %Y "$kbuild/kcore-asm/mm.s")
hand_after=$(stat -c %Y "$kbuild/kcore-asm/ret.s")
stamp_after=$(stat -c %Y "$kbuild/.kcore-built")
test "$gen_after" -gt "$gen_before"
test "$hand_after" -eq "$hand_before"
test "$stamp_after" -gt "$stamp_before"
grep -q 'system/kernel.*kcore' "$tmp/kernel-rebuild.log"

# Userland C objects depend on KCC, but objects assembled directly from
# handwritten source do not.
ubuild="$tmp/userland"
cobj="$ubuild/userland/init/libc/u.dobj"
sobj="$ubuild/userland/init/libc/crt0.dobj"
make -C "$DAIMOS_REPO/userland" BUILD_ROOT="$ubuild" \
    PDP10_PREFIX="$prefix" "$cobj" "$sobj" >/dev/null
c_before=$(stat -c %Y "$cobj")
s_before=$(stat -c %Y "$sobj")
sleep 1
touch "$prefix/bin/kcc"
make -C "$DAIMOS_REPO/userland" BUILD_ROOT="$ubuild" \
    PDP10_PREFIX="$prefix" "$cobj" "$sobj" >"$tmp/userland-rebuild.log" 2>&1
c_after=$(stat -c %Y "$cobj")
s_after=$(stat -c %Y "$sobj")
test "$c_after" -gt "$c_before"
test "$s_after" -eq "$s_before"
grep -q 'kcc .*libc/u.c' "$tmp/userland-rebuild.log"

# Native DAS phases are also compiler products and must be regenerated when
# KCC is replaced, even if the DAS sources themselves did not change.
dbuild="$tmp/das"
make -C "$DAS_ROOT" native PDP10_PREFIX="$prefix" \
    DAIMOS_REPO="$DAIMOS_REPO" NATIVE_BUILD_DIR="$dbuild" >/dev/null
d_before=$(stat -c %Y "$dbuild/das1-v1.s")
sleep 1
touch "$prefix/bin/kcc"
make -C "$DAS_ROOT" native PDP10_PREFIX="$prefix" \
    DAIMOS_REPO="$DAIMOS_REPO" NATIVE_BUILD_DIR="$dbuild" \
    >"$tmp/das-rebuild.log" 2>&1
d_after=$(stat -c %Y "$dbuild/das1-v1.s")
test "$d_after" -gt "$d_before"
grep -q 'kcc .*das_native1.c' "$tmp/das-rebuild.log"

echo "compiler dependency invalidation regression passed"
