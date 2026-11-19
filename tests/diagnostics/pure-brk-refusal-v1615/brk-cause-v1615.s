; Test-only PDP-6 monitor UUO veneer.
; Preserve the actual VM/BRK internal cause (AC2) into a user variable.
; The public dsys_brk ABI and production syscall dispatcher are unchanged.
        .text
        .globl  dsys_brk_cause_v1615
        .globl  brk_cause_v1615
dsys_brk_cause_v1615:
        move    2,1
        movei   1,052
        uuo     077,0(1)
        movem   2,brk_cause_v1615
        popj    17,
