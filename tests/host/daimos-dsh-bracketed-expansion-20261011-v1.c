/* Host-level bounded DSH expansion tests. */
#include <stdio.h>
#include "dsh.h"

static struct dsh_s6 variable;
static struct dsh_s6 value;
static int failures;

const struct dsh_s6 *dsh_var_get(const struct dsh_state *st,
    const struct dsh_s6 *name)
{
    (void)st;
    return dsh_s6_eq_text(name, "NAME") ? &value : 0;
}
int dsys_getpid(void) { return 12; }

static int make_s6(struct dsh_s6 *s, const char *str)
{
    dsh_s6_clear(s);
    while (*str) {
        if (dsh_s6_append(s, *str++) != 0)
            return -1;
    }
    return 0;
}
static void check(const char *input, const char *expected, int good)
{
    struct dsh_s6 in, out;
    int rc;
    if (make_s6(&in, input)) { ++failures; return; }
    rc = dsh_expand_mask(0, &in, 0, &out);
    if ((rc == 0) != good ||
        (good && !dsh_s6_eq_text(&out, expected))) {
        fprintf(stderr, "FAIL: %s\n", input);
        ++failures;
    }
}
int main(void)
{
    make_s6(&variable, "NAME");
    make_s6(&value, "VALUE");
    check("$[NAME]", "VALUE", 1);
    check("PRE$[NAME]POST", "PREVALUEPOST", 1);
    check("$[MISSING]", "", 1);
    check("$[]", "", 0);
    check("$[NAME", "", 0);
    check("$[1NAME]", "", 0);
    check("$[NAME:-X]", "", 0);
    check("$NAME", "VALUE", 1);
    if (failures) return 1;
    puts("DSH bracketed expansion PASS");
    return 0;
}
