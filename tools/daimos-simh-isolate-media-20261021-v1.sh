#!/bin/sh
# Give one SIMH invocation private writable media, without masking an
# unclean D6FS root or modifying the input image for later tests.
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

# Generated SIMH dofiles use literal unquoted absolute attachment paths.
# Numeric TCP listener attachments are deliberately left untouched.
awk '$1 == "attach" && $NF ~ /^\// { print $(NF-1) " " $NF }' \
    "$src_ini" > "$sourcefile"
while read -r unit src; do
        [ -n "$unit" ] || continue
        dst=$media_dir/$unit-${src##*/}
        if [ -f "$src" ]; then
                # Reflink when supported; never hard-link writable guest media.
                cp -p --reflink=auto --sparse=always "$src" "$dst"
        else
                # New output attachments may not yet exist. Others must.
                if ! grep -F " $unit $src" "$src_ini" | \
                    grep -F -- '-n' >/dev/null 2>&1; then
                        echo "missing SIMH media: $src" >&2
                        exit 1
                fi
        fi
        printf '%s\t%s\n' "$src" "$dst" >> "$mapfile"
done < "$sourcefile"

awk 'FNR == NR { path[$1] = $2; next }
     $1 == "attach" && ($NF in path) { $NF = path[$NF] }
     { print }' "$mapfile" "$src_ini" > "$dst_ini"
