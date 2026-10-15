#!/bin/sh
set -eu
: "${DAIMOS_REPO:?}"
: "${TMPDIR:=$HOME/tmp}"
work="$TMPDIR/d6codec-dxr-v079-test"
mkdir -p "$work"
cc -std=c99 -O2 -Wall -Wextra -Werror -pedantic \
 -I"$DAIMOS_REPO/tools/host" \
 "$DAIMOS_REPO/tools/host/d6codec-dxr-v079.c" \
 "$DAIMOS_REPO/tools/host/d6codec-group-v072.c" -o "$work/producer"
python3 "$(dirname "$0")/check-v079.py" "$work" "$work/producer"
cc -std=c99 -O2 -Wall -Wextra -Werror -pedantic \
 -I"$DAIMOS_REPO/tools/host" \
 "$(dirname "$0")/check-decode-v079.c" \
 "$DAIMOS_REPO/tools/host/d6codec-group-v071.c" -o "$work/decoder"
"$work/decoder" "$work/payload.bin" "$work/expected.bin"
