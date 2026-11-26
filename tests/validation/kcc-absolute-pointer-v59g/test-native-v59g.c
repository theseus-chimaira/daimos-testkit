static unsigned long *const a = (unsigned long *)020000UL;
static const unsigned long *const b = (unsigned long *)020001UL;
static unsigned long *volatile c = (unsigned long *)020002UL;
static unsigned long *const z = (unsigned long *)0;
volatile int __test_exit;
int main(void)
{
    *a = 012345UL;
    *(unsigned long *)020001UL = 076543UL;
    *c = 031415UL;
    if (*a != 012345UL || *b != 076543UL || *c != 031415UL || z)
        return 1;
    if ((unsigned long)a != 020000UL || (unsigned long)b != 020001UL ||
        (unsigned long)c != 020002UL)
        return 2;
    return 0;
}
