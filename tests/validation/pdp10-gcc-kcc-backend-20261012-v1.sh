#!/bin/sh
# Regress PDP-10 GCC's DImode bit-field extraction and 71-bit addition.
# The KCC sources formerly triggered internal compiler errors in recog.c.
set -eu

: "${TMPDIR:?TMPDIR must be set}"
: "${KCC_REPO:?KCC_REPO must be set}"
: "${DAIMOS_REPO:?DAIMOS_REPO must be set}"
: "${PDP10_PREFIX:?PDP10_PREFIX must be set}"

cc=${PDP10_GCC:-$PDP10_PREFIX/bin/pdp10-dec-none-gcc}
cc_b=${PDP10_GCC_B:-}
das=$PDP10_PREFIX/bin/das
work=$TMPDIR/pdp10-gcc-kcc-backend-20261012-v1-$$
mkdir -p "$work/include"
trap 'rm -rf "$work"' EXIT HUP INT TERM

# GCC 3.2's bare-metal target has no stdint.h; KCC needs uintptr_t only.
# This test-local header deliberately makes no changes to compiler sources.
cat > "$work/include/stdint.h" <<'EOF'
#ifndef PDP10_GCC_KCC_TEST_STDINT_V1
#define PDP10_GCC_KCC_TEST_STDINT_V1
typedef unsigned long uintptr_t;
#endif
EOF

# GCC -O0 has an independent post-reload nested-address ICE in cceval.c.
# Test the recognized back-end regressions at the working optimization
# levels; the -O0 bug must receive its own reproducer and fix.
for optimize in 1 2; do
    for name in ccdecl cceval cckirread cckpread ccpp; do
        source=$KCC_REPO/$name.c
        output=$work/$name-O$optimize
        if [ -n "$cc_b" ]; then
            "$cc" -B"$cc_b" -O"$optimize" -S -fno-builtin \
                -DHOST_DAIMOS=1 -DHOST_UNIX=0 \
                -I"$work/include" -I"$KCC_REPO/self/include" \
                -I"$DAIMOS_REPO/userland/libc" \
                "$source" -o "$output.s"
        else
            "$cc" -O"$optimize" -S -fno-builtin \
                -DHOST_DAIMOS=1 -DHOST_UNIX=0 \
                -I"$work/include" -I"$KCC_REPO/self/include" \
                -I"$DAIMOS_REPO/userland/libc" \
                "$source" -o "$output.s"
        fi
        "$das" -F -C -O "$output.dobj" "$output.s"
        echo "PASS $name -O$optimize (PDP-10 GCC and DAS)"
    done
done
