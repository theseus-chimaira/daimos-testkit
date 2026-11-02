#!/bin/sh
# Prepare a secondary TSFS set for an actual tape-root DAIMOS image.
# Source this helper after building the guest with ROOT=tape.  Only the
# boot-root profile installs the resident TSFS provider; using ROOT=auto
# (which normally selects D6FS) cannot exercise MOUNT.TSFS correctly.

daimos_tsfs_prepare_secondary_v117()
{
        tsfs_build=$1
        tsfs_work=$2
        tsfs_mktsfs=$3

        : "${tsfs_build:?missing boot build directory}"
        : "${tsfs_work:?missing test workspace}"
        : "${tsfs_mktsfs:?missing mktsfs executable}"
        test -f "$tsfs_build/tsfs-root.manifest" || return 1
        test -f "$tsfs_build/userland/mounttsfs.dxr" || return 1
        test -f "$tsfs_build/boot.ini" || return 1
        # DTC Stage1 needs a bootstream on DTC0 and cannot use an ordinary
        # TSFS root member.  The paper-tape Stage1 boot is intentional here.
        grep -q '^attach -q ptr .*stage1-ptr.pt$' \
            "$tsfs_build/boot.ini" || return 1

        # The bootable root needs the userspace mount utility and a stable
        # mount-point vnode.  Generate it as normal TSFS media, not by
        # patching a running image or installing the provider on D6FS.
        cp "$tsfs_build/tsfs-root.manifest" "$tsfs_work/boot-root.manifest"
        printf 'D /MOUNT/DT0 0755 0 0\n' >> "$tsfs_work/boot-root.manifest"
        printf 'F /SYSTEM/EXEC/MOUNT.TSFS %s 0555 0 0\n' \
            "$tsfs_build/userland/mounttsfs.dxr" \
            >> "$tsfs_work/boot-root.manifest"
        "$tsfs_mktsfs" -n 1 -i 1:1 -g 1 \
            -m "$tsfs_work/boot-root.manifest" \
            -o "$tsfs_work/media/boot-root" >/dev/null
        cp "$tsfs_work/media/boot-root0.dta" \
            "$tsfs_build/media/dtc0.tap"

        # Keep the complete independent set in its own three DTC units;
        # DTC0 remains a valid OS root throughout the mount test.
        awk -v media="$tsfs_work/media" '
            /^attach -q dtc3 / {
                print
                for (unit = 0; unit < 3; ++unit)
                    printf "attach -q dtc%d %s/member%d.dta\n", \
                        unit + 4, media, unit
                inserted = 1
                next
            }
            { print }
            END { if (!inserted) exit 1 }
        ' "$tsfs_build/boot.ini" > "$tsfs_build/boot.tsfs-secondary.ini"
}
