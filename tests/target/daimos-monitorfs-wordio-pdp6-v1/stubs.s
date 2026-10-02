        .text
        .globl  kret_zero
        .globl  kret_one
        .globl  kret_neg1
        .globl  kret_busy
kret_zero:      setz    1,
                popj    17,
kret_one:       movei   1,1
                popj    17,
kret_neg1:      seto    1,
                popj    17,
kret_busy:      hrroi   1,3
                popj    17,

        .globl  blockset_tail_blocks
blockset_tail_blocks:
        seto    1,
        popj    17,
