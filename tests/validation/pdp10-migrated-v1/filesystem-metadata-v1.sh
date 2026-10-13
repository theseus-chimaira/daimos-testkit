#!/bin/sh
set -eu

ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/../../.." && pwd)
DAIMOS_SRC=${DAIMOS_SRC:-$(CDPATH= cd -- "$ROOT/../DAIMOS" && pwd)}
PDP10_TOOLS_SRC=${PDP10_TOOLS_SRC:-$DAIMOS_SRC/tools/host}
PDP10_PREFIX=${PDP10_PREFIX:-/usr/local}
MKTSFS=${MKTSFS:-$PDP10_PREFIX/bin/mktsfs}
TSFSCHECK=${TSFSCHECK:-$PDP10_PREFIX/bin/tsfscheck}
: "${TMPDIR:=$HOME/tmp}"
CASE_DIR="$TMPDIR/pdp10-c-testkit-fsmeta-v1"

fail()
{
        echo "filesystem-metadata-v1: $*" >&2
        exit 1
}

require_text()
{
        file=$1
        text=$2
        grep -F "$text" "$file" >/dev/null || fail "$file lacks: $text"
}

reject_text()
{
        file=$1
        text=$2
        if grep -F "$text" "$file" >/dev/null; then
                fail "$file unexpectedly contains: $text"
        fi
}

rm -rf "$CASE_DIR"
mkdir -p "$CASE_DIR"
trap 'rm -rf "$CASE_DIR"' 0 1 2 3 15

# Credential ABI and common VFS setattr contract.
require_text "$DAIMOS_SRC/system/kernel/fs/vfs.h" '#define VFS_ID_MASK          0777U'
require_text "$DAIMOS_SRC/system/kernel/fs/vfs.h" '#define VFS_SETATTR_CHOWN    0100000U'
require_text "$DAIMOS_SRC/system/kernel/fs/vfs.h" '#define VFS_SETATTR_UTIME    0100001U'
require_text "$DAIMOS_SRC/system/kernel/fs/file_runtime.s" '.globl  vfs_current_owner'
require_text "$DAIMOS_SRC/system/kernel/fs/vfs.s" 'vfs_setattr:'

# MEMFS keeps owner and mtime in the block-aligned dynamic metadata area.
require_text "$DAIMOS_SRC/system/kernel/fs/memfs.h" '#define MEMFS_SNAPSHOT_VERSION       2UL'
require_text "$DAIMOS_SRC/system/kernel/fs/memfs.h" '#define MEMFS_OWNER_OFFSET           01000U'
require_text "$DAIMOS_SRC/system/kernel/fs/memfs.h" '#define MEMFS_OWNER_WORDS            0100U'
require_text "$DAIMOS_SRC/system/kernel/fs/memfs.h" '#define MEMFS_MTIME_OFFSET           01100U'
require_text "$DAIMOS_SRC/system/kernel/fs/memfs.h" '#define MEMFS_METADATA_WORDS         01200U'
require_text "$DAIMOS_SRC/system/kernel/fs/memfs_runtime.s" 'pushj   17,vfs_current_owner'
require_text "$DAIMOS_SRC/system/kernel/fs/memfs_runtime.s" 'pushj   17,pclk_time36'

# DTFS media remains unchanged: mount ownership is packed into runtime state.
require_text "$DAIMOS_SRC/system/kernel/fs/dtfs.c" 'media | (vfs_current_owner() << 18U)'
require_text "$DAIMOS_SRC/system/kernel/fs/dtfs_runtime.s" 'dtfs_stat_owner:'

# TSFS V1.1 keeps the eight-word record and embeds mode/UID/GID in spare fields.
require_text "$PDP10_TOOLS_SRC/tsfs-format.h" '#define TSFS_FORMAT_MINOR 1U'
require_text "$PDP10_TOOLS_SRC/tsfs-format.h" '#define TSFS_FILE_WORDS              8U'
require_text "$PDP10_TOOLS_SRC/tsfs-format.h" '#define TSFS_FILE_MODE_SHIFT         6U'
require_text "$PDP10_TOOLS_SRC/tsfs-format.h" '#define TSFS_FILE_ID_MASK            0777U'
require_text "$DAIMOS_SRC/system/kernel/fs/tsfs.h" '#define TSFS_FILE_MODE_SHIFT       6U'
require_text "$DAIMOS_SRC/system/kernel/fs/vfs.s" 'mtime unknown unless provider supplies it'
reject_text "$DAIMOS_SRC/system/kernel/fs/tsfs_runtime.s" 'pclk_time36'

# Round-trip a small attribute-bearing V1.1 TSFS image through the host tools.
test -x "$MKTSFS" || fail "missing $MKTSFS"
test -x "$TSFSCHECK" || fail "missing $TSFSCHECK"
python3 - "$CASE_DIR/payload.words" <<'PY'
import struct
import sys
with open(sys.argv[1], "wb") as f:
    f.write(struct.pack("<Q", 0o123456))
PY
cat > "$CASE_DIR/manifest" <<EOF2
D /SYSTEM 0555 0 0
D /CONFIG 0755 0 0
F /SYSTEM/EXEC $CASE_DIR/payload.words 0555 1 2
F /CONFIG/PASSWD $CASE_DIR/payload.words 0600 0 0
EOF2
"$MKTSFS" -n 1 -i 1:1 -g 1 -m "$CASE_DIR/manifest" -o "$CASE_DIR/root"
"$TSFSCHECK" "$CASE_DIR/root0.dta" | grep -F 'TSFS OK' >/dev/null ||
        fail "TSFS V1.1 verification failed"

echo 'filesystem-metadata-v1: PASS'
