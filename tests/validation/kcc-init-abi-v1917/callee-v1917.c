/* Separately compiled callee: no caller-specific preservation contract. */
struct proc {
        unsigned long flags;
};

unsigned long observed_v1917;

unsigned long
disable_v1917(void)
{
        return 0200UL;
}

int
check_v1917(unsigned int slot, struct proc *p, unsigned int mode)
{
        return slot == 1U && p != (struct proc *)0 && mode == 2U &&
            p->flags == 0200123UL;
}

void
restore_v1917(unsigned long saved)
{
        /* Preserve a preceding observe failure for the caller oracle. */
        if (observed_v1917 != 0777777UL)
                observed_v1917 = saved;
}

void
observe_v1917(unsigned int n)
{
        observed_v1917 = n == 01234U ? n : 0777777UL;
}
