; Link-only stubs for FILE entry points outside file_component.
; The test executes the production file_runtime.s component scanner only.
        .data
        .globl  file_table
file_table:             .word 0
        .globl  vfs_namespace_root
vfs_namespace_root:     .word 0
        .globl  proc_table
proc_table:              .word 0
        .globl  proc_current_slot
proc_current_slot:       .word 0

        .text
        .globl  file_parent_path
        .globl  vfs_parent_name
        .globl  vfs_sync
        .globl  vfs_read_words
        .globl  vfs_readdir
        .globl  vfs_write_words
        .globl  vfs_readchar
        .globl  vfs_writechar
        .globl  vfs_symlink
        .globl  vfs_rename
        .globl  vfs_mkdir
        .globl  vfs_mkfifo
        .globl  vfs_lookup
        .globl  vfs_unlink
        .globl  vfs_truncate
        .globl  vfs_stat
        .globl  file_lookup_path
        .globl  lpt_putchar
file_parent_path:
vfs_parent_name:
vfs_read_words:
vfs_readdir:
vfs_write_words:
vfs_readchar:
vfs_writechar:
vfs_symlink:
vfs_rename:
vfs_mkdir:
vfs_mkfifo:
vfs_lookup:
vfs_unlink:
vfs_truncate:
vfs_stat:
file_lookup_path:
lpt_putchar:
        seto    1,
        popj    17,

vfs_sync:
        setz    1,
        popj    17,

        .globl  pipe_readchar
        .globl  pipe_writechar
        .globl  pipe_add_ref
        .globl  pipe_close_ref
        .globl  pipe_fifo_detach
pipe_readchar:
pipe_writechar:
        seto    1,
        popj    17,
pipe_add_ref:
        popj    17,
pipe_close_ref:
        setz    1,
        popj    17,
pipe_fifo_detach:
        popj    17,
