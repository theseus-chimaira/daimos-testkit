#!/bin/sh
# Check fixed DSH source limits without running a PDP-6 image.
set -eu
: "${DAIMOS_REPO:?DAIMOS_REPO must be set}"
header=$DAIMOS_REPO/userland/dsh/dsh.h
editor=$DAIMOS_REPO/userland/dsh/dsh.c
[ -r "$header" ] && [ -r "$editor" ] || exit 1
check_limit()
{
    actual=$(awk -v key="$1" '$1 == "#define" && $2 == key { print $3 }' "$header")
    [ "$actual" = "$2" ] || {
        echo "DSH resource contract changed: $1 expected $2 got $actual" >&2
        exit 1
    }
}
check_limit DSH_S6_MAX_CHARS 36U
check_limit DSH_LINE_MAX_CHARS 180U
check_limit DSH_MAX_ARGS 20U
check_limit DSH_MAX_VARS 64U
check_limit DSH_MAX_ALIASES 8U
check_limit DSH_MAX_JOBS 4U
check_limit DSH_MAX_FUNCS 4U
check_limit DSH_FUNC_MAX_NODES 8U
check_limit DSH_FUNC_MAX_CALLS 3U
check_limit DSH_SCRIPT_MAX_TOKENS 32U
awk '$1 == "#define" && $2 == "DSH_HISTORY_MAX" && $3 == "4U" { ok=1 } END { exit !ok }' "$editor"
echo 'DSH resource contract PASS: 11 fixed limits'
