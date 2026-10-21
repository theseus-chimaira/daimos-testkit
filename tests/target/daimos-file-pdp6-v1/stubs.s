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
        .globl  vfs_create
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
vfs_create:
vfs_readdir:
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

        .globl  proc_swap_backing_busy
proc_swap_backing_busy:
        setz    1,
        popj    17,


; Deterministic bulk-I/O providers for the FILE word-I/O validation.
; Record the production ABI and return short positive transfers so FILE must
; advance its descriptor offset by the returned count rather than NWORDS.
vfs_read_words:
        movem   1,file_test_read_node
        movem   2,file_test_read_off
        movem   3,file_test_read_buf
        movem   4,file_test_read_count
        movei   1,2
        popj    17,

vfs_write_words:
        movem   1,file_test_write_node
        movem   2,file_test_write_off
        movem   3,file_test_write_buf
        movem   4,file_test_write_count
        movei   1,3
        popj    17,

vfs_sync:
        setz    1,
        popj    17,

; Targeted device-word I/O fixture: use the actual one-word MINIT-style
; patchable KCORE jump entries, not direct calls to the test service.
; Every FILE device path must pass mapped buffer/count in AC1/AC2 and
; return through the common offset-accounting code after service POPJ.
        .globl file_test_patch_devices
        .globl file_test_device_buf
        .globl file_test_device_count
        .globl file_test_device_slot
        .globl tty_write_s6rec_jump
        .globl ptp_write_words_jump
        .globl cp_write_words_jump
        .globl lpt_write_s6rec_jump
        .globl dpy_write_words_jump
        .globl wcnsls_write_words_jump
        .globl tty_read_s6rec_jump
        .globl ptr_read_words_jump
        .globl cr_read_words_jump
file_test_patch_devices:
        move    1,[jrst file_test_device_service]
        movem   1,tty_write_s6rec_jump
        movem   1,ptp_write_words_jump
        movem   1,cp_write_words_jump
        movem   1,lpt_write_s6rec_jump
        movem   1,dpy_write_words_jump
        movem   1,wcnsls_write_words_jump
        movem   1,tty_read_s6rec_jump
        movem   1,ptr_read_words_jump
        movem   1,cr_read_words_jump
        popj    17,
file_test_device_service:
        movem   1,file_test_device_buf
        movem   2,file_test_device_count
        movem   4,file_test_device_slot
        movei   1,2                  ; deterministic short transfer
        popj    17,

        .globl  pipe_readchar
        .globl  pipe_writechar
        .globl  pipe_fifo_open
        .globl  pipe_add_ref
        .globl  pipe_close_ref
        .globl  pipe_fifo_detach
pipe_readchar:
pipe_writechar:
        seto    1,
        popj    17,
pipe_fifo_open:
        setz    1,
        popj    17,
pipe_add_ref:
        popj    17,
pipe_close_ref:
        setz    1,
        popj    17,
pipe_fifo_detach:
        popj    17,

        .bss
        .globl file_test_read_node
        .globl file_test_read_off
        .globl file_test_read_buf
        .globl file_test_read_count
        .globl file_test_write_node
        .globl file_test_write_off
        .globl file_test_write_buf
        .globl file_test_write_count
file_test_read_node:    .block 1
file_test_read_off:     .block 1
file_test_read_buf:     .block 1
file_test_read_count:   .block 1
file_test_write_node:   .block 1
file_test_write_off:    .block 1
file_test_write_buf:    .block 1
file_test_write_count:  .block 1
file_test_device_buf:   .block 1
file_test_device_count: .block 1
file_test_device_slot:  .block 1
