#!/bin/sh
# Verify GNU/BSD make parsing and selected expanded inventories without building.
set -eu
: "${KCC_REPO:?}" "${BMAKE:?}" "${MAKESYSPATH:?}"
cd "$KCC_REPO"
for variable in NATIVE_BUILD_SRCS NATIVE_KCPP_MODULES NATIVE_KPARSE_MODULES NATIVE_KGEN_MODULES NATIVE_KOPT_MODULES HOST_BUILD_SRCS; do
    g=$(gmake -sf Makefile --eval="check-kcc-make-vars:;@printf '%s\\n' \$($variable)" check-kcc-make-vars 2>/dev/null) || exit 1
    b=$("$BMAKE" -v "$variable") || exit 1
    [ "$(printf '%s' "$g" | tr -s '[:space:]' ' ')" = "$(printf '%s' "$b" | tr -s '[:space:]' ' ')" ] || { echo "variable mismatch: $variable"; exit 1; }
done
gmake -n -f Makefile clean >/dev/null
"$BMAKE" -n -f Makefile clean >/dev/null
echo 'PASS: GNU/BSD Make parse and inventory comparisons'
