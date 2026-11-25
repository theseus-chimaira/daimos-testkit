; Controlled D6FS/TSFS identity success for historical isolated DXR fixtures.
; No real mounted filesystem or physical proof is exercised here.
; Unexpected requests (including DTFS) still refuse.
        .text
        .globl fs_provider_reg_call
fs_provider_reg_call:
        caie    7,6
        cain    7,7
        jrst    media_accept_v1928
        jrst    media_refuse_v1927
media_accept_v1928:
        caie    6,030
        jrst    media_refuse_v1927
        setz    1,
        popj    17,
media_refuse_v1927:
        seto    1,
        popj    17,
