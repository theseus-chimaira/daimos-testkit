#!/bin/sh
# Bounded-stack graph discovery using production KIR writer routines.
set -eu
: "${KCC_REPO:?}" "${TMPDIR:?}"
w=$(mktemp -d "$TMPDIR/kir-queue-20261010-v1.XXXXXX")
trap 'rm -rf "$w"' EXIT HUP INT TERM
cat > "$w/check.c" <<'C99'
#include "cckirwrite.c"
#include <stdio.h>
NODE *vlaboundexpr_v11(TYPE *t) { (void)t; return 0; }
SYMBOL *vlaboundsym_v11(TYPE *t) { (void)t; return 0; }
SYMBOL *vlabase_v11(SYMBOL *s) { (void)s; return 0; }
SYMBOL *vlaobjmarkget_v12(SYMBOL *s) { (void)s; return 0; }
int main(void)
{
    enum { NN=12000, NS=9000, NT=5000 };
    static NODE n[NN];
    static SYMBOL s[NS];
    static TYPE t[NT];
    struct kir_wgraph g;
    unsigned i, in=0, is=0, it=0;
    memset(&g, 0, sizeof(g));
    for (i=0; i<NN; ++i) {
        n[i].Nop=Q_CASE;
        n[i].Nright=&n[(i+1)%NN];
    }
    for (i=0; i<NS; ++i) {
        s[i].Sflags=SF_LOCAL;
        s[i].Sclass=SC_MEMBER;
        s[i].Ssmnext=&s[(i+1)%NS];
    }
    for (i=0; i<NT; ++i) {
        t[i].Tspec=TS_PTR;
        t[i].Tsubt=&t[(i+1)%NT];
    }
    if (addnode(&g,n)!=1 || addtype(&g,t)!=1 || addsym(&g,s)==0) return 1;
    while (!g.failed && (in<g.nn || is<g.ns || it<g.nt)) {
        if (in<g.nn) visit_node(&g,g.nodes[in++]);
        else if (it<g.nt) visit_type(&g,g.types[it++]);
        else visit_symbol(&g,g.syms[is++].symbol);
    }
    if (g.failed || g.nn!=NN || g.ns!=NS || g.nt!=NT) return 2;
    if (nodeid(&g,&n[NN-1])!=NN || typeid(&g,&t[NT-1])!=NT ||
        symid(&g,&s[NS-1])==0) return 3;
    printf("PASS: %u nodes %u symbols %u types\n",g.nn,g.ns,g.nt);
    return 0;
}
C99
"${HOST_CC:-cc}" -std=c99 -O2 -ffunction-sections -fdata-sections \
    -I"$KCC_REPO" "$w/check.c" -Wl,--gc-sections -o "$w/check"
(ulimit -s 64; "$w/check")
