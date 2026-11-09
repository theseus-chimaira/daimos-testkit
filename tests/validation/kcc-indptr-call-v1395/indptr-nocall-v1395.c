/* Call-free loops must keep the existing induction-pointer optimization. */
extern int *global_ptr;
int *slots_nocall[5];

void fill_nocall(void)
{
    int i;
    for (i = 0; i < 5; ++i)
        slots_nocall[i] = global_ptr;
}
