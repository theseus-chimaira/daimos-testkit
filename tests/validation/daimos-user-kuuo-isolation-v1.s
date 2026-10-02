; A low PDP-6 programmed operator issued from USER mode follows the LUUO
; path, not the monitor-UUO executive path.  Install a controlled user LUUO
; vector at virtual word 041, then restore the original word after the trap.
        .text
        .globl  daimos_test_low_uuo

daimos_test_low_uuo:
        move    1,041
        movem   1,daimos_test_low_uuo_saved
        move    1,daimos_test_low_uuo_vector
        movem   1,041
        uuo     017,4
        ; Reaching here would mean opcode 017 did not follow the LUUO vector.
        move    2,daimos_test_low_uuo_saved
        movem   2,041
        setz    1,
        popj    17,

daimos_test_low_uuo_handler:
        move    2,daimos_test_low_uuo_saved
        movem   2,041
        seto    1,
        popj    17,

daimos_test_low_uuo_vector:
        jrst    daimos_test_low_uuo_handler

daimos_test_low_uuo_saved:
        .long   0
