/* Independent semantic contract for the one-word DAS directive table.
 * Keep every accepted spelling explicit; the test must not reuse the
 * production table to derive its expected token values.  C89 only. */
#define DAS_HOST 1
#define DAS_NO_MAIN 1
#include "das.c"

struct token_case_v1871 {
    const char *name;
    enum das_token token;
};

static const struct token_case_v1871 accepted_v1871[] = {
    {"ALIGN", DAS_TOK_ALIGN},
    {"ASCII", DAS_TOK_ASCII},
    {"ASCIZ", DAS_TOK_ASCIZ},
    {"BLOCK", DAS_TOK_BLOCK},
    {"BSS", DAS_TOK_BSS},
    {"BYTE", DAS_TOK_BYTE},
    {"CODE", DAS_TOK_TEXT},
    {"COMM", DAS_TOK_COMM},
    {"COMMON", DAS_TOK_COMM},
    {"CONST", DAS_TOK_DATA},
    {"DATA", DAS_TOK_DATA},
    {"DIRECTIVE", DAS_TOK_DIRECTIVE},
    {"END", DAS_TOK_NO_WORDS},
    {"ENDPS", DAS_TOK_NO_WORDS},
    {"ENTRY", DAS_TOK_ENTRY},
    {"EQU", DAS_TOK_EQU},
    {"ERROR", DAS_TOK_ERROR},
    {"EXP", DAS_TOK_EXP},
    {"EXTERN", DAS_TOK_EXTERN},
    {"FILE", DAS_TOK_NO_WORDS},
    {"GIW", DAS_TOK_GIW},
    {"GLOBAL", DAS_TOK_GLOBAL},
    {"GLOBL", DAS_TOK_GLOBAL},
    {"IDENT", DAS_TOK_NO_WORDS},
    {"LCOMM", DAS_TOK_LCOMM},
    {"LOC", DAS_TOK_NO_WORDS},
    {"LONG", DAS_TOK_LONG},
    {"ORG", DAS_TOK_ORG},
    {"OWGBP", DAS_TOK_OWGBP},
    {"POINT", DAS_TOK_POINT},
    {"PSECT", DAS_TOK_PSECT},
    {"RADIX", DAS_TOK_RADIX},
    {"RODATA", DAS_TOK_DATA},
    {"SECT", DAS_TOK_PSECT},
    {"SECTION", DAS_TOK_PSECT},
    {"SET", DAS_TOK_SET},
    {"SIXBIT", DAS_TOK_SIXBIT},
    {"SPACE", DAS_TOK_SPACE},
    {"TEXT", DAS_TOK_TEXT},
    {"TITLE", DAS_TOK_NO_WORDS},
    {"WARNING", DAS_TOK_WARNING},
    {"WORD", DAS_TOK_WORD},
    {"ZERO", DAS_TOK_SPACE},
    {"P2ALIGN", DAS_TOK_ALIGN}
};

static const char *const rejected_v1871[] = {
    "IF", "IFDEF", "IFNDEF", "ELSE", "ENDIF", "P2ALIGX",
    "DIRECX", "WORDX", "SIXBI", "ASCII_", "LOWER", "SECTIX",
    "LOCD", "TWOPASS", "2ALIGN"
};

int main(void)
{
    static struct asmctx ctx;
    unsigned int i;
    unsigned int j;
    char lower[32];

    for (i = 0U; i < sizeof(accepted_v1871) /
            sizeof(accepted_v1871[0]); i++) {
        const struct token_case_v1871 *c;

        c = &accepted_v1871[i];
        if (classify_token(&ctx, c->name) != c->token) {
            fprintf(stderr, "DAS token mismatch: %s\n", c->name);
            return 1;
        }
        for (j = 0U; c->name[j] != 0 && j < sizeof(lower) - 1U; j++) {
            unsigned char ch;

            ch = (unsigned char)c->name[j];
            lower[j] = (char)(ch >= 'A' && ch <= 'Z' ?
                ch - 'A' + 'a' : ch);
        }
        lower[j] = 0;
        if (classify_token(&ctx, lower) != c->token) {
            fprintf(stderr, "DAS lowercase token mismatch: %s\n", lower);
            return 2;
        }
    }
    for (i = 0U; i < sizeof(rejected_v1871) /
            sizeof(rejected_v1871[0]); i++) {
        if (classify_token(&ctx, rejected_v1871[i]) != DAS_TOK_OTHER) {
            fprintf(stderr, "DAS unexpected token: %s\n",
                    rejected_v1871[i]);
            return 3;
        }
    }
    /* Existing DAS classification compares the first six characters.
     * An overlong token sharing all six remains a match; this is not
     * a new parser feature introduced by the compact representation. */
    if (classify_token(&ctx, "EXTERN_") != DAS_TOK_EXTERN)
        return 4;
    printf("PASS: all 43 DAS directive entries, P2ALIGN and invalid keys\n");
    return 0;
}
