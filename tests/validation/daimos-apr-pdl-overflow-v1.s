/*
 * Generate a real PDP-6 pushdown-list overflow in user mode.
 *
 * A PDP-6 PUSH increments both halves of the pushdown pointer.  Starting the
 * left half at 0777777 makes that increment carry through C1, which sets the
 * APR pushdown-overflow condition.  RH 0100 keeps the actual memory write well
 * inside the test process if the CPU were to continue past the condition.
 */
        .text
        .globl apr_pdl_overflow
apr_pdl_overflow:
        move    16,[0777777,,000100]
        push    16,[0]
        popj    17,
