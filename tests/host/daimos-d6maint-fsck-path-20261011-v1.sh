#!/bin/sh
# A bare mkd6fs command must locate its companion checker using PATH.
set -eu
: "${DAIMOS_REPO:?}" "${TMPDIR:?}"
work=$(mktemp -d "$TMPDIR/daimos-d6maint-fsck-path-20261011-v1.XXXXXX")
trap 'rm -rf "$work"' EXIT HUP INT TERM
cat > "$work/test.c" <<'SOURCE'
#include "d6maint.h"
int main(void)
{
    return d6m_run_fsck("mkd6fs", "test-volume", 4U, 0);
}
SOURCE
cat > "$work/d6fsck" <<'SOURCE'
#!/bin/sh
test "$#" -eq 4 && test "$1" = -n && test "$2" = 4 &&
test "$3" = -d && test "$4" = test-volume
SOURCE
chmod +x "$work/d6fsck"
"${HOST_CC:-cc}" -std=c99 -O2 -I"$DAIMOS_REPO/tools/host" \
    "$work/test.c" "$DAIMOS_REPO/tools/host/d6maint.c" -o "$work/test"
PATH="$work:$PATH" "$work/test"
printf '%s\n' 'PASS: bare mkd6fs locates d6fsck via PATH'
