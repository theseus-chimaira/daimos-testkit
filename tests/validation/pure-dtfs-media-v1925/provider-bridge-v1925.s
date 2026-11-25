; Verify register-dispatch ABI, then simulate serialized media proof.
        .text
        .globl fs_provider_reg_call
fs_provider_reg_call:
        cail    7,5
        caile   7,7
        jrst    media_bad_v1925
media_provider_v1927:
        caie    6,030
        jrst    media_bad_v1925
        jrst    media_check_v1925
media_bad_v1925:
        seto    1,
        popj    17,
