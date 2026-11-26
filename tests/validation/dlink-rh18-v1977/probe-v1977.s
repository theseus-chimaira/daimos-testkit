; Negative LOCAL_RH18 and SYMBOL_RH18 effective addresses. The index
; contributes the opposite displacement; both loads must see exact data.
        .text
        .globl rh18_probe_v1977
        .globl rh18_external_v1977
rh18_probe_v1977:
        movei   2,0100000
        move    1,local_v1977-0100000(2)
        came    1,[012345670123]
        jrst    rh18_fail_v1977
        move    1,rh18_external_v1977-0100000(2)
        came    1,[076543210765]
        jrst    rh18_fail_v1977
        setz    1,
        popj    17,
rh18_fail_v1977:
        movei   1,1
        popj    17,
        .data
local_v1977: .word 012345670123
