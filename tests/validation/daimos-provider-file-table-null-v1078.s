; Isolated provider gateway fixtures have no process u-area.
; A null FILE table preserves the ordinary sleep/revalidate path.
        .data
        .globl file_table
file_table: .word 0
        .text
        .globl vfs_readonly
        .globl proc_swap_backing_busy
vfs_readonly:
proc_swap_backing_busy:
        seto    1,
        popj    17,

        .text
        .globl proc_exec_reserve_v1933
proc_exec_reserve_v1933:
        seto    1,
        popj    17,
