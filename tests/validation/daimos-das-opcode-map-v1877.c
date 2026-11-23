/* Independent frozen mnemonic/opcode oracle for DAS v1877 compaction.
 * The expected rows are fixed data captured before changing the table;
 * they are not generated from the implementation being tested.
 * ISO C89 only.
 */
#define DAS_HOST 1
#define DAS_NO_MAIN 1
#include "das.c"

static int check_name(const char *name, unsigned int expected_op,
                      int expected_nonbase)
{
    int nonbase;
    int opcode;

    nonbase = -1;
    opcode = lookup_op(name, &nonbase);
    if (opcode != (int)expected_op || nonbase != expected_nonbase) {
        fprintf(stderr, "opcode %s: got %04o/%d expected %04o/%d\n",
                name, opcode, nonbase, expected_op, expected_nonbase);
        return 1;
    }
    /* The host optimizer and macro parser pass a prepacked six-bit key
     * directly.  This interface must remain correct after any compact
     * decoder change, even when the public name lookup is correct. */
    nonbase = -1;
    opcode = lookup_op_mn(sixbit_mn(name), &nonbase);
    if (opcode != (int)expected_op || nonbase != expected_nonbase) {
        fprintf(stderr, "internal opcode %s: got %04o/%d expected %04o/%d\n",
                name, opcode, nonbase, expected_op, expected_nonbase);
        return 2;
    }
    return 0;
}

int main(int argc, char **argv)
{
    char line[128];
    char name[32];
    char lower[32];
    unsigned int op;
    unsigned int count;
    int nonbase;
    unsigned int i;
    FILE *oracle;

    if (argc != 2)
        return 2;
    oracle = fopen(argv[1], "r");
    if (oracle == 0)
        return 3;
    count = 0U;
    while (fgets(line, sizeof(line), oracle) != 0) {
        if (line[0] == '#')
            continue;
        if (sscanf(line, "%31s %o %d", name, &op, &nonbase) != 3) {
            fclose(oracle);
            return 4;
        }
        if (check_name(name, op, nonbase) != 0) {
            fclose(oracle);
            return 5;
        }
        for (i = 0U; name[i] != 0 && i + 1U < sizeof(lower); ++i) {
            unsigned char ch;

            ch = (unsigned char)name[i];
            lower[i] = (char)(ch >= 'A' && ch <= 'Z' ?
                ch - 'A' + 'a' : ch);
        }
        lower[i] = 0;
        if (check_name(lower, op, nonbase) != 0) {
            fclose(oracle);
            return 6;
        }
        count++;
    }
    fclose(oracle);
    if (count != 390U)
        return 7;
    if (lookup_op("NOTANOP", &nonbase) >= 0 ||
        lookup_op("ANDCZ", &nonbase) >= 0 ||
        lookup_op("XMOVEJ", &nonbase) >= 0)
        return 8;
    puts("PASS: all 390 frozen DAS opcode mappings and lowercase aliases");
    return 0;
}
