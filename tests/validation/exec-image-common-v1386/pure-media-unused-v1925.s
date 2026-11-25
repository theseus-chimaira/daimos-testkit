; No DTFS provider in this isolated image-loader fixture. A request is
; an unexpected failure, never a fabricated physical identity success.
        .text
        .globl fs_provider_reg_call
fs_provider_reg_call:
        seto    1,
        popj    17,
