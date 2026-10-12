#!/bin/sh
# Build both kernel startup C and all native userspace with the selected
# PDP-10 compiler. Never reuse objects across toolchains.
set -eu
: "${DAIMOS_REPO:?}"
: "${PDP10_PREFIX:?}"
: "${TMPDIR:?}"
: "${COMPILER:=kcc}"
case "$COMPILER" in
gcc) selected=pdp10-dec-none-gcc ;;
kcc) selected=kcc ;;
*) echo "invalid compiler $COMPILER" >&2; exit 2 ;;
esac
work="$TMPDIR/daimos-compiler-selection-20261012-v1-$COMPILER-$$"
mkdir -p "$work"
trap 'rm -rf "$work"' EXIT HUP INT TERM
mkdir -p "$work/bin"
for name in kcc pdp10-dec-none-gcc; do
    cat > "$work/bin/$name" <<'EOF_COMPILER'
#!/bin/sh
printf '%s\n' "${0##*/}" >> "$DAIMOS_COMPILER_TRACE"
exec "$PDP10_PREFIX/bin/${0##*/}" "$@"
EOF_COMPILER
    chmod +x "$work/bin/$name"
done
export DAIMOS_COMPILER_TRACE="$work/compiler-trace.log"
export PATH="$work/bin:$PDP10_PREFIX/bin:$PATH"
make -C "$DAIMOS_REPO/system/kernel" kinit \
    BUILD="$work/kernel" COMPILER="$COMPILER" \
    PDP10_PREFIX="$PDP10_PREFIX" > "$work/kernel.log" 2>&1 || {
        tail -40 "$work/kernel.log" >&2; exit 1;
    }
grep -q "^$selected$" "$work/compiler-trace.log" || {
    echo "kernel did not select $selected" >&2; exit 1;
}
if grep -v -x "$selected" "$work/compiler-trace.log" | grep .; then
    echo 'kernel invoked a different C compiler' >&2; exit 1;
fi
: > "$work/compiler-trace.log"
make -C "$DAIMOS_REPO/userland" build \
    BUILD_ROOT="$work/userland-build" COMPILER="$COMPILER" \
    PDP10_PREFIX="$PDP10_PREFIX" > "$work/userland.log" 2>&1 || {
        tail -40 "$work/userland.log" >&2; exit 1;
    }
grep -q "^$selected$" "$work/compiler-trace.log" || {
    echo "userland did not select $selected" >&2; exit 1;
}
if grep -v -x "$selected" "$work/compiler-trace.log" | grep .; then
    echo 'userland invoked a different C compiler' >&2; exit 1;
fi
case "$COMPILER" in
gcc)
    if grep -q '^kcc ' "$work/userland.log"; then
        echo 'GCC userland silently invoked KCC' >&2; exit 1;
    fi
    test -f "$work/userland-build/userland/init/libc/gcc_startup.dobj"
    ;;
kcc)
    if grep -q '^pdp10-dec-none-gcc ' "$work/userland.log"; then
        echo 'KCC userland silently invoked GCC' >&2; exit 1;
    fi
    test ! -f "$work/userland-build/userland/init/libc/gcc_startup.dobj"
    ;;
esac
test -s "$work/userland-build/userland/init.dxr"
test -s "$work/userland-build/userland/dsh.dxr"
echo "daimos-compiler-selection-20261012-v1: PASS $COMPILER"
