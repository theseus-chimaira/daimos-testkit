/* Direct host-side DSH lexer/parser regression tests (C89). */
#include <stdio.h>
#include <string.h>
#include "dsh_parse.h"
#include "dsh_lex.h"

int u_put_s6(int fd, const kword_t *p)
{ (void)fd; (void)p; return -1; }
static int failures;
static void check(int ok, const char *name)
{
    if (!ok) { fprintf(stderr, "FAIL: %s\n", name); ++failures; }
}
static int line_make(struct dsh_line *line, const char *s)
{
    unsigned int i, w, sh;
    dsh_line_clear(line);
    for (i = 0; s[i]; ++i) {
        if (i >= DSH_LINE_MAX_CHARS || s[i] < 040 || s[i] > 0137)
            return -1;
        w = i / 6U;
        sh = 30U - (i % 6U) * 6U;
        line->words[w] |= (kword_t)(s[i] - 040) << sh;
    }
    line->len = i;
    return 0;
}
static void lex_case(const char *name, const char *s, int want_rc,
                     unsigned int want_n, int type0, const char *word0)
{
    struct dsh_line line;
    struct dsh_token tokens[DSH_LEX_MAX_TOKENS];
    unsigned int n = 0;
    int err = -1, rc;
    if (line_make(&line, s) != 0) { check(0, name); return; }
    rc = dsh_lex_s6_line(&line, tokens, DSH_LEX_MAX_TOKENS, &n, &err);
    check(rc == want_rc, name);
    if (rc != DSH_OK) return;
    check(n == want_n, name);
    if (n != 0 && type0 >= 0) {
        check(DSH_TOKEN_TYPE(&tokens[0]) == type0, name);
        if (word0) check(dsh_s6_eq_text(&tokens[0].text, word0), name);
    }
}
static void limit_cases(void)
{
    struct dsh_line line;
    struct dsh_token tokens[DSH_LEX_MAX_TOKENS];
    struct dsh_node nodes[DSH_PARSE_MAX_NODES];
    unsigned int count, root, used;
    int err, rc;
    check(line_make(&line, "A B C D E") == 0, "limit input");
    rc = dsh_lex_s6_line(&line, tokens, 2U, &count, &err);
    check(rc == DSH_E_OVERFLOW, "lexer token capacity");
    rc = dsh_parse_s6_line(&line, nodes, 0U, &root, &used, &err);
    check(rc != DSH_OK, "parser zero node capacity");
}
static void parse_case(const char *name, const char *s, int expected)
{
    struct dsh_line line;
    struct dsh_node nodes[DSH_PARSE_MAX_NODES];
    unsigned int root = DSH_NONE, used = 0;
    int err = -1, rc;
    if (line_make(&line, s) != 0) { check(0, name); return; }
    rc = dsh_parse_s6_line(&line, nodes, DSH_PARSE_MAX_NODES,
                           &root, &used, &err);
    check((rc == DSH_OK) == expected, name);
    if (rc == DSH_OK) check(root != DSH_NONE && used <= DSH_PARSE_MAX_NODES, name);
}
int main(void)
{
    lex_case("boundary comment", "ECHO A # COMMENT", DSH_OK, 2, DSH_T_WORD, "ECHO");
    lex_case("internal hash", "ECHO A#B", DSH_OK, 2, DSH_T_WORD, "ECHO");
    lex_case("empty quotes", "'' \"\"", DSH_OK, 2, DSH_T_WORD, "");
    lex_case("quoted keyword", "'IF'", DSH_OK, 1, DSH_T_WORD, "IF");
    lex_case("pipeline", "A!B", DSH_OK, 3, DSH_T_WORD, "A");
    lex_case("append", "A>>B", DSH_OK, 3, DSH_T_WORD, "A");
    lex_case("background", "A&B", DSH_OK, 3, DSH_T_WORD, "A");
    lex_case("unclosed quote", "ECHO 'ABC", DSH_E_CHAR, 0, -1, 0);
    parse_case("simple", "ECHO HI", 1);
    parse_case("if", "IF TRUE THEN ECHO OK FI", 1);
    parse_case("for", "FOR I IN A B DO ECHO $I DONE", 1);
    parse_case("while", "WHILE TRUE DO ECHO OK DONE", 1);
    parse_case("until", "UNTIL TRUE DO ECHO OK DONE", 1);
    parse_case("begin", "BEGIN ECHO A; ECHO B END", 1);
    parse_case("pipe", "ECHO A ! CAT", 1);
    parse_case("missing fi", "IF TRUE THEN ECHO A", 0);
    parse_case("missing done", "WHILE TRUE DO ECHO A", 0);
    parse_case("stray paren", "ECHO A )", 0);
    parse_case("simple substitution", "ECHO $(ECHO A)", 1);
    parse_case("bare substitution", "$(ECHO A)", 1);
    parse_case("empty substitution", "ECHO $()", 0);
    parse_case("unclosed substitution", "ECHO $(ECHO A", 0);
    parse_case("nested substitution", "ECHO $(ECHO $(ECHO A))", 0);
    parse_case("multiple substitutions", "ECHO $(ECHO A) $(ECHO B)", 0);
    limit_cases();
    if (failures) return 1;
    puts("DSH direct lexer/parser PASS");
    return 0;
}
