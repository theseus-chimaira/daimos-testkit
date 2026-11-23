/* Frozen pre-v1883 extended opcode mappings, valid ISO C89. */
#define DAS_HOST 1
#define DAS_NO_MAIN 1
#include "das.c"

int main(int argc, char **argv)
{
    FILE *source;
    char line[128];
    char name[32];
    char lower[32];
    unsigned int expected;
    unsigned int count;
    unsigned int i;
    int opcode;
    int nonbase;

    if (argc != 2)
        return 1;
    source = fopen(argv[1], "r");
    if (source == 0)
        return 2;
    count = 0U;
    while (fgets(line, sizeof(line), source) != 0) {
        if (line[0] == '#')
            continue;
        if (sscanf(line, "%31s %o", name, &expected) != 2)
            return 3;
        nonbase = -1;
        opcode = lookup_op(name, &nonbase);
        if (opcode != (int)expected || nonbase != 1) {
            fprintf(stderr, "extended opcode mismatch: %s\n", name);
            return 4;
        }
        for (i = 0U; name[i] != 0 && i < sizeof(lower) - 1U; ++i)
            lower[i] = (char)tolower((unsigned char)name[i]);
        lower[i] = 0;
        nonbase = -1;
        if (lookup_op(lower, &nonbase) != (int)expected || nonbase != 1)
            return 5;
        count++;
    }
    fclose(source);
    if (count != 24U)
        return 6;
    if (lookup_op("PMOVEX", &nonbase) >= 0 ||
        lookup_op("UMOVEX", &nonbase) >= 0 ||
        lookup_op("APRIDQ", &nonbase) >= 0)
        return 7;
    puts("PASS: all 24 frozen extended opcode mappings v1883");
    return 0;
}
