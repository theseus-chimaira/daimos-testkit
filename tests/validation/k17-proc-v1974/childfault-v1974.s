; Native KA10 unassigned instruction, same opcode as v1964 trap probe.
        .text
        .globl child_unassigned_v1974
child_unassigned_v1974:
        .word 0105000000000
        popj 17,
