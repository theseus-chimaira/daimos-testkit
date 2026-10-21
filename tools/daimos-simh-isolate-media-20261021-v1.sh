#!/bin/sh
# Give one SIMH invocation private writable media.  Do not hide an unclean
# D6FS root by mounting/recovering it: clone an unchanged CLEAN build image
# before the guest can set the D6FS DIRTY transaction marker.
set -eu

if [ "$#" -ne 3 ]; then
        echo 'usage: daimos-simh-isolate-media SRC.INI DEST.INI MEDIA-DIR' >&2
        exit 2
fi
src_ini=$1
dst_ini=$2
media_dir=$3
mkdir -p "$media_dir"
mapfile=$media_dir/attach-paths.map
sourcefile=$media_dir/attach-sources.map
: > "$mapfile"

# SIMH dofiles in this testkit specify literal, unquoted absolute media
# paths in attach statements.  TCP listener ports are numeric and untouched.
awk '$1 == "attach" && $NF ~ /^\// { print $(NF-1) " " $NF }' \
    "$src_ini" > "$sourcefile"
while read -r unit src; do
        [ -n "$unit" ] || continue
        dst=$media_dir/$unit-${src##*/}
        if [ -f "$src" ]; then
                # Sparse DSK/DRM files are large logically but small on disk.
                # Reflink where possible; never hard-link mutable media.
                cp -p --reflink=auto --sparse=always "$src" "$dst"
        else
                # An attach -n output may not exist until SIMH creates it.
                # Read-only sources without -n must always be real files.
                if ! grep -F " $unit $src" "$src_ini" | grep -F -- '-n' >/dev/null 2>&1; then
                        echo "missing SIMH media: $src" >&2
                        exit 1
                fi
        fi
        printf '%s\t%s\n' "$src" "$dst" >> "$mapfile"
done < "$sourcefile"

awk 'FNR == NR { path[$1] = $2; next }
     $1 == "attach" && ($NF in path) { $NF = path[$NF] }
     { print }' "$mapfile" "$src_ini" > "$dst_ini"
