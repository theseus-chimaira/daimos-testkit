/* Validate DAS phase-1 opcode membership against the frozen v1876 table.
 * This builds the phase-1-only membership path, not the phase-2 decoder.
 * ISO C89 only.
 */
#define DAS_HOST 1
#define DAS_NATIVE_PHASE1_ONLY 1
#define DAS_NO_MAIN 1
#include "das.c"

int main(int argc, char **argv)
{
    FILE *source;
    char name[32];
    unsigned int code;
    unsigned int count;
    int nonbase;
    char line[128];

    if (argc != 2)
        return 1;
    source = fopen(argv[1], "r");
    if (source == 0)
        return 2;
    count = 0U;
    while (fgets(line, sizeof(line), source) != 0) {
        if (line[0] == '#')
            continue;
        if (sscanf(line, "%31s %o %d", name, &code, &nonbase) != 3)
            return 3;
        if (lookup_op_mn(sixbit_mn(name), 0) < 0) {
            fprintf(stderr, "missing phase1 opcode: %s\n", name);
            return 4;
        }
        count++;
    }
    fclose(source);
    if (count != 390U)
        return 5;
    if (lookup_op_mn(sixbit_mn("NOTANOP"), 0) >= 0 ||
        lookup_op_mn(sixbit_mn("ADDQ"), 0) >= 0 ||
        lookup_op_mn(sixbit_mn("SETCMZ"), 0) >= 0)
        return 6;
    puts("PASS: 390 frozen phase1 opcode names with packed triples v1882");
    return 0;
}
