        .text
        .globl daimos_module_runtime_init_lh
daimos_module_runtime_init_lh:
        hrlm    2,0(1)
        popj    17,

        .globl fs_move_words
fs_move_words:
        jumpe   3,fs_move_words_done
        move    4,2
        hrl     4,1
        add     2,3
        subi    2,1
        blt     4,(2)
fs_move_words_done:
        popj    17,

        .bss
        .globl pdp10_pi_level1_dispatch_jump
pdp10_pi_level1_dispatch_jump: .block 1
        .globl pdp10_pi_level2_dispatch_jump
pdp10_pi_level2_dispatch_jump: .block 1
        .globl pdp10_pi_level3_dispatch_jump
pdp10_pi_level3_dispatch_jump: .block 1
        .globl pdp10_pi_level4_dispatch_jump
pdp10_pi_level4_dispatch_jump: .block 1
        .globl pdp10_pi_level5_dispatch_jump
pdp10_pi_level5_dispatch_jump: .block 1
        .globl pdp10_pi_level6_dispatch_jump
pdp10_pi_level6_dispatch_jump: .block 1
        .globl native_sys_putchar_call
native_sys_putchar_call: .block 1
        .globl native_sys_getchar_call
native_sys_getchar_call: .block 1
        .globl tty_write_s6rec_jump
tty_write_s6rec_jump: .block 1
        .globl tty_read_s6rec_jump
tty_read_s6rec_jump: .block 1
        .globl ptr_read_words_jump
ptr_read_words_jump: .block 1
        .globl ptp_write_words_jump
ptp_write_words_jump: .block 1
        .globl cr_read_words_jump
cr_read_words_jump: .block 1
        .globl cp_write_words_jump
cp_write_words_jump: .block 1
        .globl lpt_putchar_jump
lpt_putchar_jump: .block 1
        .globl lpt_write_s6rec_jump
lpt_write_s6rec_jump: .block 1
        .globl dpy_write_words_jump
dpy_write_words_jump: .block 1
        .globl sys_dtc_read_block_jump
sys_dtc_read_block_jump: .block 1
        .globl sys_dtc_write_block_jump
sys_dtc_write_block_jump: .block 1
        .globl storage_pi_dsk_jump
storage_pi_dsk_jump: .block 1
        .globl storage_dct_dsk_jump
storage_dct_dsk_jump: .block 1
        .globl storage_pi_tape_jump
storage_pi_tape_jump: .block 1
        .globl storage_dct_tape_jump
storage_dct_tape_jump: .block 1
        .globl storage_clock_dsk_jump
storage_clock_dsk_jump: .block 1
        .globl dsk270_read_jump
dsk270_read_jump: .block 1
        .globl dsk270_write_jump
dsk270_write_jump: .block 1
        .globl drm236_read_jump
drm236_read_jump: .block 1
        .globl drm236_write_jump
drm236_write_jump: .block 1
        .globl fs_memfs_service_jump
fs_memfs_service_jump: .block 1
        .globl sys_memfs_usage_call
sys_memfs_usage_call: .block 1
        .globl fs_dtfs_service_jump
fs_dtfs_service_jump: .block 1
        .globl sys_dtfs_format_jump
sys_dtfs_format_jump: .block 1
        .globl sys_dtfs_mount_jump
sys_dtfs_mount_jump: .block 1
        .globl fs_d6fs_service_jump
fs_d6fs_service_jump: .block 1
        .globl fs_tsfs_service_jump
fs_tsfs_service_jump: .block 1
        .globl memfs_reclaim_jump
memfs_reclaim_jump: .block 1
        .globl memfs_shutdown_jump
memfs_shutdown_jump: .block 1
        .globl blockset_runtime_service_jump
blockset_runtime_service_jump: .block 1
