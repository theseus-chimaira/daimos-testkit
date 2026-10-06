        .text
        .globl fs_provider_reg_call
; Minimal provider used by the stack-frame regression.  STAT deliberately
; writes every word in struct vfs_stat, including uid/gid at offsets 4 and 5.
fs_provider_reg_call:
        caie    6,3
        jrst    vfs_stat_frame_provider_fail
        movei   0,1                    ; VFS_TYPE_DIR
        movem   0,0(2)
        movei   0,0777
        movem   0,1(2)
        movei   0,0123
        movem   0,2(2)
        movei   0,045
        movem   0,3(2)
        movei   0,012
        movem   0,4(2)
        movei   0,034
        movem   0,5(2)
        setz    1,
        popj    17,
vfs_stat_frame_provider_fail:
        seto    1,
        popj    17,

        .globl mfsdev_lookup
        .globl mfsproc_lookup
        .globl mfsdev_readdir
        .globl mfsproc_readdir
        .globl mfsdev_stat
        .globl mfsproc_stat
        .globl mfsproc_format_slot
        .globl pipe_fifo_mount_busy
        .globl proc_swap_backing_busy
        .globl proc_swap_mount_busy
        .globl pipe_read_words
        .globl pipe_write_words
mfsdev_lookup:
mfsproc_lookup:
mfsdev_readdir:
mfsproc_readdir:
mfsdev_stat:
mfsproc_stat:
mfsproc_format_slot:
pipe_fifo_mount_busy:
proc_swap_backing_busy:
proc_swap_mount_busy:
        setz    1,
        popj    17,
pipe_read_words:
pipe_write_words:
        seto    1,
        popj    17,

        .globl mfsdom_read_words
        .globl mfsproc_read_words
        .globl mfsdev_readchar
mfsdom_read_words:
mfsproc_read_words:
mfsdev_readchar:
        seto    1,
        popj    17,

        .globl file_unlock_mount
file_unlock_mount:
        setz    1,
        popj    17,
