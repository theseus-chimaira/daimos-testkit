/* A declaration initializer is an executable call boundary. */
struct proc {
        unsigned long flags;
};

extern unsigned long disable_v1917(void);
extern int check_v1917(unsigned int, struct proc *, unsigned int);
extern void restore_v1917(unsigned long);
extern void observe_v1917(unsigned int);
extern unsigned long observed_v1917;

unsigned long __test_exit;
static struct proc victim;

static int
unlock_v1917(unsigned int slot, struct proc *p, unsigned int mode)
{
        unsigned long saved = disable_v1917();
        int ok = check_v1917(slot, p, mode);

        if (ok)
                p->flags &= ~0200000UL;
        restore_v1917(saved);
        return ok;
}

/* A sole read at a bare call must also survive earlier initializers. */
static unsigned int
first_read_v1917(unsigned int n)
{
        unsigned long saved = disable_v1917();
        observe_v1917(n);
        restore_v1917(saved);
        return 1U;
}

/* C99 declarations after statements have the same execution semantics. */
static unsigned int
late_decl_v1917(unsigned int n)
{
        observed_v1917 = 0UL;
        unsigned long saved = disable_v1917();
        observe_v1917(n);
        restore_v1917(saved);
        return 1U;
}

/* The ordinary one-read call-free prefix remains legal. */
static unsigned int
plain_decl_v1917(unsigned int n)
{
        unsigned int marker = 0123U;
        observe_v1917(n);
        return marker;
}

int
main(void)
{
        victim.flags = 0200123UL;
        if (unlock_v1917(1U, &victim, 2U) != 1 ||
            victim.flags != 0123UL || observed_v1917 != 0200UL)
                return 1;
        victim.flags = 0200123UL;
        if (unlock_v1917(1U, &victim, 3U) != 0 ||
            victim.flags != 0200123UL || observed_v1917 != 0200UL)
                return 2;
        if (first_read_v1917(01234U) != 1U ||
            observed_v1917 != 0200UL)
                return 3;
        if (late_decl_v1917(01234U) != 1U ||
            observed_v1917 != 0200UL)
                return 4;
        if (plain_decl_v1917(01234U) != 0123U ||
            observed_v1917 != 01234UL)
                return 5;
        return 0;
}
