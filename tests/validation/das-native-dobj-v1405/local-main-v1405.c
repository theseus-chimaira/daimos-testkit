/* C89 local .data relocation must not escape the object. */
static int v1405_local_value = 7;

int main(void)
{
    return v1405_local_value;
}
