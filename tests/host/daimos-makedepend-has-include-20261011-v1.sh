#!/bin/sh
# Regression for quoted, angle, and source-relative __has_include lookup.
set -eu
: "${DAIMOS_REPO:?}" "${TMPDIR:?}"
work=$(mktemp -d "$TMPDIR/daimos-makedepend-has-include-20261011-v1.XXXXXX")
trap 'rm -rf "$work"' EXIT HUP INT TERM
src="$DAIMOS_REPO/userland/makedepend"
"${HOST_CC:-cc}" -O2 -std=c99 -D_DEFAULT_SOURCE -DHAVE_RENAME=1 \
    '-DOBJSUFFIX=".o"' '-DINCLUDEDIR="/usr/include"' \
    "$src/main.c" "$src/include.c" "$src/parse.c" "$src/pr.c" \
    "$src/cppsetup.c" "$src/ifparser.c" -o "$work/makedepend"
mkdir "$work/inc" "$work/src"
printf '#define FOUND 1\n' > "$work/found.h"
printf '#define ANGLE 1\n' > "$work/inc/angle.h"
printf '#define NESTED 1\n' > "$work/src/nested.h"
cat > "$work/probe.c" <<'EOF'
#if __has_include("found.h")
#include "found.h"
#else
#include "missing-quoted.h"
#endif
#if __has_include(<angle.h>)
#include <angle.h>
#else
#include "missing-angle.h"
#endif
#if __has_include("missing.h")
#include "missing.h"
#else
#include "found.h"
#endif
EOF
cat > "$work/src/nested.c" <<'EOF'
#if __has_include("nested.h")
#include "nested.h"
#else
#include "missing-nested.h"
#endif
EOF
printf '# DO NOT DELETE\n' > "$work/Makefile"
(cd "$work" && ./makedepend -f Makefile -Iinc probe.c src/nested.c)
grep -q '^probe.o: .*found.h' "$work/Makefile"
grep -q 'angle.h' "$work/Makefile"
grep -q 'src/nested.h' "$work/Makefile"
if grep -q 'missing-' "$work/Makefile"; then
    echo 'makedepend selected a nonexistent conditional header' >&2
    exit 1
fi
printf '%s\n' 'daimos-makedepend-has-include: PASS'
