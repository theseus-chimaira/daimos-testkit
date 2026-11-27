#!/bin/sh
# Generate local labels from the exact built objects; reject stale source.
set -eu
: "${DAIMOS_REPO:?}" "${PDP10_PREFIX:?}"
b=$(cd "$1" && pwd)
w=$(cd "$2" && pwd)
mm="$DAIMOS_REPO/system/kernel/mm"
for part in mm vm commit finish; do
    case "$part" in
        mm) src="$b/kcore-asm/mm.s"; obj=mm.dobj;;
        vm) src="$b/kcore-asm/vm_backend_pdp6.s"; obj=vm_backend_pdp6.dobj;;
        commit) src="$b/pure-directory-commit-v1983.dobj.s"; obj=pure-directory-commit-v1983.dobj;;
        finish) src="$mm/mm_pure_bitmap_finish_v1664.s"; obj=pure-directory-finish-v1983.dobj;;
    esac
    "$PDP10_PREFIX/bin/das" -C -F -L "$w/$part.labels" -O "$w/$part.label.dobj" "$src"
    cmp "$w/$part.label.dobj" "$b/$obj"
    echo "PASS exact source-linked $part object"
done
