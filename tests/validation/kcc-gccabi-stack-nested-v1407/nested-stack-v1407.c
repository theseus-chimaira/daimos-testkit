/* C89: outgoing fifth/sixth arguments must survive nested call spills. */
static int hash_v1407(int value)
{
    return value + 3;
}

static int fold5_v1407(int a, int b, int c, int d, int e)
{
    return a + 2 * b + 4 * c + 8 * d + 16 * e;
}

static int fold6_v1407(int a, int b, int c, int d, int e, int f)
{
    return a + 2 * b + 4 * c + 8 * d + 16 * e + 32 * f;
}

static int nested5_v1407(int a, int b, int d, int e)
{
    return fold5_v1407(a, b, hash_v1407(b), d, e);
}

static int nested6_v1407(int a, int b, int d, int e, int f)
{
    return fold6_v1407(a, b, hash_v1407(b), d, e, f);
}

struct record_v1407 {
    unsigned long value;
    unsigned long hash;
    int section;
};

static unsigned long string_hash_v1407(const char *name)
{
    unsigned long hash;

    hash = 0UL;
    while (*name != '\0') {
        hash = ((hash << 5) + hash +
                (unsigned long)(unsigned char)*name) & 0777777777777UL;
        name++;
    }
    return hash;
}

static void record5_v1407(struct record_v1407 *record,
                         const char *name, unsigned long hash,
                         int section, unsigned long value)
{
    (void)name;
    record->value = value;
    record->hash = hash;
    record->section = section;
}

static void nested_record_v1407(struct record_v1407 *record,
                               const char *name, int section,
                               unsigned long value)
{
    record5_v1407(record, name, string_hash_v1407(name),
                  section, value);
}

int main(void)
{
    struct record_v1407 record;

    record.value = 0UL;
    record.hash = 0UL;
    record.section = 0;
    nested_record_v1407(&record, "main", 3, 0123456UL);
    if (record.value != 0123456UL || record.section != 3 ||
        record.hash != string_hash_v1407("main"))
        return 5;
    if (nested5_v1407(1, 2, 4, 5) != 137)
        return 3;
    if (nested6_v1407(1, 2, 4, 5, 6) != 329)
        return 4;
    return 7;
}
