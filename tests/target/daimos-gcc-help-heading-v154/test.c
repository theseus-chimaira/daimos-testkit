/* GCC PDP-6 optimized stack CHAR indexing across 36-bit word boundaries.
 * The assembler fixture fills the buffer through its word address so that
 * neither C stores nor the compiler under test can mask broken C reads.
 */
extern int fill_local(char *buffer, unsigned int capacity);

int
stack_char_test(void)
{
        char line[256];

        if (fill_local(line, sizeof(line)) < 0)
                return 0;
        return line[0] == '#' && line[1] == '#' && line[2] == ' ' &&
               line[3] == '@' && line[4] == '?' && line[5] == 'O' &&
               line[6] == 'P' && line[7] == 'E' && line[8] == 'R' && line[9] == 'A' &&
               line[10] == 'N' && line[11] == 'D' && line[12] == 'S' &&
               line[13] == 0;
}
