; Isolated provider gateway fixtures have no process u-area.
; A null FILE table preserves the ordinary sleep/revalidate path.
        .data
        .globl file_table
file_table: .word 0
