/* DSH angle-parameter tokenization and ordinary redirection isolation. */
#include <stdio.h>
#include "dsh_lex.h"

int
u_put_s6(int fd, const kword_t *words)
{
        (void)fd;
        (void)words;
        return -1;
}

static unsigned int failures;

static int
pack_line(struct dsh_line *line, const char *s)
{
        unsigned int i;
        unsigned int sh;
        int ch;

        dsh_line_clear(line);
        for (i = 0U; s[i] != 0; ++i) {
                ch = (unsigned char)s[i];
                if (ch < 040 || ch > 0137 || i >= DSH_LINE_MAX_CHARS)
                        return -1;
                sh = 30U - (i % 6U) * 6U;
                line->words[i / 6U] |= (kword_t)(ch - 040) << sh;
        }
        line->len = i;
        return 0;
}

static void
check(const char *label, const char *line_text, int expected_rc,
    unsigned int expected_count, int expression_literal,
    int expression_quoted)
{
        struct dsh_line line;
        struct dsh_token tokens[DSH_LEX_MAX_TOKENS];
        unsigned int count;
        int pos;
        int rc;

        if (pack_line(&line, line_text) != 0) {
                fprintf(stderr, "FAIL %s: input\n", label);
                ++failures;
                return;
        }
        rc = dsh_lex_s6_line(&line, tokens, DSH_LEX_MAX_TOKENS,
            &count, &pos);
        if (rc != expected_rc ||
            (rc == DSH_OK && count != expected_count)) {
                fprintf(stderr, "FAIL %s: rc=%d tokens=%u\n", label,
                    rc, count);
                ++failures;
                return;
        }
        if (rc != DSH_OK || expected_count < 2U ||
            expression_literal < 0)
                return;
        if (DSH_TOKEN_TYPE(&tokens[1]) != DSH_T_WORD ||
            (!!(tokens[1].literal_mask & 1UL)) != expression_literal ||
            (!!(tokens[1].quote_mask & 1UL)) != expression_quoted) {
                fprintf(stderr, "FAIL %s: token flags\n", label);
                ++failures;
        }
}

int
main(void)
{
        check("basic", "ECHO $<V>", DSH_OK, 2U, 0, 0);
        check("default", "ECHO $<V:-A B>", DSH_OK, 2U, 0, 0);
        check("embedded operators", "ECHO $<V:-A&B>", DSH_OK, 2U, 0, 0);
        check("adjacent suffix", "ECHO $<V>X", DSH_OK, 2U, 0, 0);
        check("redirect out", "ECHO $<V> > OUT", DSH_OK, 4U, 0, 0);
        check("append", "ECHO $<V> >> OUT", DSH_OK, 4U, 0, 0);
        check("redirect in", "CAT < IN", DSH_OK, 3U, -1, 0);
        check("single quoted", "ECHO '$<V>'", DSH_OK, 2U, 1, 1);
        check("double quoted", "ECHO \"$<V>\"", DSH_OK, 2U, 0, 1);
        check("escaped dollar", "ECHO \\$<V>", DSH_OK, 2U, 1, 1);
        check("missing terminator", "ECHO $<V", DSH_E_CHAR, 0U, 0, 0);
        if (failures != 0U)
                return 1;
        puts("PASS angle parameter lexer v1");
        return 0;
}
