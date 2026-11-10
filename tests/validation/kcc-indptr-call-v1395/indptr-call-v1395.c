/* A function call must not move a loop-carried destination address. */
extern int *fetch_value(int);
int *slots[5];

void fill_slots(void)
{
    int i;
    for (i = 0; i < 5; ++i)
        slots[i] = fetch_value(i);
}
