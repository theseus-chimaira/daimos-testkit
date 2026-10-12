/* Regress PDP-10 GCC's packed multidimensional byte-array indexing.
 * A 103-character row must advance 103 9-bit bytes, not 25 words.
 * Both direct array references and pointer decay must use that row. */
static char rows[16][103];

void
set_array(int row, int col, char ch)
{
        rows[row][col] = ch;
}

char
get_array(int row, int col)
{
        return rows[row][col];
}

char *
row_array(int row)
{
        return rows[row];
}

void
set_row(int row, int col, char ch)
{
        char *p = rows[row];
        p[col] = ch;
}
