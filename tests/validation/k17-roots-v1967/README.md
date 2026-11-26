# KA10 root profiles without RM10 v1967

Build fresh, separate image directories (do not reuse a writable D6FS
image stopped at INIT, because the production mount marks it DIRTY):

    export TMPDIR=${TMPDIR:-$HOME/tmp}
    w=$(mktemp -d "$TMPDIR/k17-roots-v1967.XXXXXX")
    make -C "$DAIMOS_REPO/system/boot/pdp6" DAIMOS_MACHINE=ka10 ROOT=tape BUILD="$w/tape" image
    make -C "$DAIMOS_REPO/system/boot/pdp6" DAIMOS_MACHINE=ka10 ROOT=disk BUILD="$w/disk" image
    python3 -B native-v1967.py "$w/tape" "$w/disk" "$PDP10_PREFIX" "$w/native"

Both boots copy the root media before execution. INIT is a boot witness,
not shell or process qualification. The mounted VFS provider is read
back directly: TSFS=7 and D6FS=6. No RM10 media are attached. A D6FS
image interrupted during a writable mount needs the existing recovery
procedure; an ordinary writable mount intentionally rejects DIRTY media.
The two RM10-present configurations remain open pending driver integration.
