/*
 * Host-only disk detach fixtures cannot execute PDP-6 machine code.
 * The real packed-owner release is separately tested by v1609 on
 * native PDP-6 with the actual MM owner scan and VM destroy leaf.
 * These old tests contain only DISK/RESIDENT process records and
 * deliberately reject any attempt to enter a PACKED owner path.
 */
#include "proc.h"
#include "proc_packed_v1.h"

int
proc_storage_expect_v30(unsigned int slot, unsigned int mode)
{
        (void)slot;
        return mode == PROC_STORAGE_PACKED ? -1 : 0;
}

int
pdp6_pure_detach_v1609(int slot, struct proc *p, kword_t backing)
{
        (void)slot;
        (void)p;
        (void)backing;
        return -1;
}
