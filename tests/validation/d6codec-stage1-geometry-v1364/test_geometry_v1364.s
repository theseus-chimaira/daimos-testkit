/* Physical memory geometry: original KINIT header lengths in 18-bit halves. */
        .text
        .globl main
        .globl d6stage_geometry_v1364
main:
        ; Normal 32K compressed image.
        movei 1,1
        movei 2,2
        move 3,[0100000]
        movei 4,0400
        pushj 17,d6stage_geometry_v1364
        jumpn 0,fail1
        ; Exactly enough KINIT output plus stack reserve.
        move 1,[047400]
        setz 2,
        pushj 17,d6stage_geometry_v1364
        jumpn 0,fail2
        ; A single additional output word would violate stack reserve.
        move 1,[047401]
        pushj 17,d6stage_geometry_v1364
        camn 0,[-1]
        jrst check_stage_max
        jrst fail3
check_stage_max:
        movei 1,1
        move 2,[047777]
        pushj 17,d6stage_geometry_v1364
        jumpn 0,fail4
        ; One additional compressed word exceeds the actual 32K core.
        move 2,[050000]
        pushj 17,d6stage_geometry_v1364
        camn 0,[-1]
        jrst check_zero_input
        jrst fail5
check_zero_input:
        setz 1,
        setz 2,
        pushj 17,d6stage_geometry_v1364
        camn 0,[-1]
        jrst check_full_profile
        jrst fail6
check_full_profile:
        ; Full 256K profile leaves a larger staging region.
        movei 1,1
        move 2,[0747777]
        move 3,[01000000]
        pushj 17,d6stage_geometry_v1364
        jumpn 0,fail7
        move 2,[0750000]
        pushj 17,d6stage_geometry_v1364
        camn 0,[-1]
        jrst verify_registers
        jrst fail8
verify_registers:
        ; No scratch AC except AC0 is allowed to be clobbered.
        movei 1,1
        movei 2,2
        move 3,[01000000]
        movei 4,0400
        pushj 17,d6stage_geometry_v1364
        jumpn 0,fail9
        caie 1,1
        jrst fail9
        caie 2,2
        jrst fail9
        came 3,[01000000]
        jrst fail9
        caie 4,0400
        jrst fail9
        setz 1,
        popj 17,
fail1: movei 1,1
        popj 17,
fail2: movei 1,2
        popj 17,
fail3: movei 1,3
        popj 17,
fail4: movei 1,4
        popj 17,
fail5: movei 1,5
        popj 17,
fail6: movei 1,6
        popj 17,
fail7: movei 1,7
        popj 17,
fail8: movei 1,010
        popj 17,
fail9: movei 1,011
        popj 17,
        .bss
        .globl __test_exit
__test_exit: .block 1
