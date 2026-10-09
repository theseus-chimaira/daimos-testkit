#!/bin/sh
# Regression for the D6FS resize helper accidentally placed immediately
# after its own PUSHJ.  The POPJ then returns into the helper a second time,
# consumes an unrelated stack word and can branch to location 1.
set -eu

: "${DAIMOS_REPO:?DAIMOS_REPO must be set}"
source="$DAIMOS_REPO/system/kernel/fs/d6fs_provider_mutation.s"
test -r "$source"

awk '
function canonical(s) {
    sub(/;.*/, "", s)
    gsub(/^[ \t]+|[ \t]+$/, "", s)
    return tolower(s)
}
{
    text = canonical($0)
    if (text == "")
        next
    if (pending != "" && text == pending ":") {
        printf "%s:%d: PUSHJ returns directly into %s\n", \
            FILENAME, FNR, pending > "/dev/stderr"
        bad = 1
    }
    pending = ""
    if (text ~ /^pushj[ \t]+17[ \t]*,[ \t]*[a-z_][a-z0-9_]*$/) {
        count = split(text, args, ",")
        if (count == 2) {
            pending = args[2]
            gsub(/^[ \t]+|[ \t]+$/, "", pending)
        }
    }
    if (text == "d6fs_resize_decode_extent:")
        decode++
    if (text == "d6fs_resize_extend_loop:")
        continuation++
}
END {
    if (bad || decode != 1 || continuation != 1)
        exit 1
}
' "$source"

echo 'daimos-d6fs-resize-call-flow-20261009-v1: PASS'
