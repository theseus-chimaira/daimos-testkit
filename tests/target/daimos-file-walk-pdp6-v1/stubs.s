        .data
        .globl  proc_table
proc_table:              .word 0
        .globl  proc_current_slot
proc_current_slot:       .word 0

        .text
        .globl  vfs_mkfifo
        .globl  pipe_fifo_open
        .globl  pipe_readchar
        .globl  pipe_writechar
        .globl  pipe_add_ref
        .globl  pipe_close_ref
        .globl  pipe_fifo_detach
        .globl  lpt_putchar

; Link-only dependencies of file.c/file_runtime.s which the pathname-walk test
; does not exercise.  Keep these local to the standalone target harness.
vfs_mkfifo:
pipe_readchar:
pipe_writechar:
pipe_close_ref:
lpt_putchar:
        seto    1,
        popj    17,

pipe_fifo_open:
        setz    1,
        popj    17,

pipe_add_ref:
pipe_fifo_detach:
        popj    17,
