#!/bin/sh
# A target SIMH test only certifies the DSH binary actually installed in its
# boot fixture.  Build-directory names and source branch labels prove nothing.
set -eu
if [ "$#" -ne 2 ]; then
        echo 'usage: daimos-dsh-image-provenance REFERENCE.DXR INSTALLED.DXR' >&2
        exit 2
fi
reference=$1
installed=$2
if [ ! -f "$reference" ] || [ ! -f "$installed" ]; then
        echo 'DSH provenance: missing reference or installed DXR' >&2
        exit 2
fi
printf 'reference SHA-256: '
sha256sum "$reference" | cut -d ' ' -f 1
printf 'installed SHA-256: '
sha256sum "$installed" | cut -d ' ' -f 1
if ! cmp -s "$reference" "$installed"; then
        echo 'DSH provenance: FAIL (different executable bytes)' >&2
        exit 1
fi
printf 'DSH provenance: PASS (byte-identical executable)\n'
