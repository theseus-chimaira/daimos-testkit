#!/bin/sh
# Native libc allocator exercised on host using a word-addressed fake brk.
set -eu
: "${DAIMOS_REPO:?}"
: "${TMPDIR:=${HOME}/tmp}"
mkdir -p "$TMPDIR"
work=$(mktemp -d "$TMPDIR/daimos-realloc-v1.XXXXXX")
trap 'rm -rf "$work"' EXIT HUP INT TERM
python3 - "$DAIMOS_REPO/userland/libc/stdlib.c" "$work/allocator.c" <<'PY'
import pathlib,sys
s=pathlib.Path(sys.argv[1]).read_text()
start=s.index('void *\nmalloc(')
end=s.index('\nstatic void\nqsort_swap',start)
part=s[start:end].replace("extern void *memset(void *, int, unsigned int);", "").replace("extern void *memcpy(void *, void *, unsigned int);", "")
# Host addresses count bytes; PDP-10 C addresses count machine words.
# Translate only brk growth increments in the extracted test harness.
part=part.replace('dsys_brk(next)', 'dsys_brk(next)')
part=part.replace('current + (kword_t)need', 'current + (kword_t)need * sizeof(kword_t)')
part=part.replace('current + (kword_t)(extra - nextfree->words)', 'current + (kword_t)(extra - nextfree->words) * sizeof(kword_t)')
part=part.replace('current + (kword_t)extra', 'current + (kword_t)extra * sizeof(kword_t)')
# Keep allocator unchanged; replace only the DAIMOS syscall layer and names.
pre='''#include <stddef.h>
#include <stdint.h>
#include <string.h>
#include <limits.h>
#define malloc daimos_malloc
#define free daimos_free
#define realloc daimos_realloc
#define calloc daimos_calloc
#define kword_t uintptr_t
#define LIBC_USER_ADDR_MASK ((uintptr_t)~(uintptr_t)0)
struct heap_block { unsigned int words; struct heap_block *next; };
static struct heap_block *heap_free;
static uintptr_t arena[262144];
static unsigned used;
static uintptr_t dsys_brk(uintptr_t next) {
    uintptr_t curr=(uintptr_t)(arena+used);
    if (next==0) return curr;
    if (next< (uintptr_t)arena || next>(uintptr_t)(arena+262144)) return (uintptr_t)-1;
    if ((next-(uintptr_t)arena)%sizeof(uintptr_t)) return (uintptr_t)-1;
    used=(unsigned)((next-(uintptr_t)arena)/sizeof(uintptr_t));
    return next;
}
static unsigned int heap_header_words(void) { return (sizeof(struct heap_block)+sizeof(uintptr_t)-1)/sizeof(uintptr_t); }
static unsigned int heap_data_words(unsigned int n) { return (n+sizeof(uintptr_t)-1)/sizeof(uintptr_t); }
'''
# The native code compares break relative to an address mask; host uses a mock
# low-end address mask, not the target PDP-6 18-bit address-space limit.
post='''\n#include <assert.h>
int main(void) {
    unsigned char *a,*b,*c,*d; unsigned before;
    unsigned i;
    a=daimos_malloc(90); b=daimos_malloc(180); c=daimos_malloc(90);
    assert(a&&b&&c);
    memset(a,0x5a,90); memset(c,0x33,90);
    daimos_free(b);
    before=used; d=daimos_realloc(a,220);
    assert(d==a && used==before);
    for(i=0;i<90;i++) assert(a[i]==0x5a);
    before=used; d=daimos_realloc(c,400);
    assert(d==c && used>before);
    for(i=0;i<90;i++) assert(c[i]==0x33);
    before=used; d=daimos_realloc(c,40);
    assert(d==c && used==before);
    a=daimos_realloc(a,60);
    daimos_free(a); daimos_free(c);
    /* Reuse adjacent coalesced fragments; no new break extension. */
    before=used; a=daimos_malloc(180);
    assert(a && used==before);
    daimos_free(a);
    /* Nonadjacent growth must move, preserve bytes and free old storage. */
    a=daimos_malloc(64); b=daimos_malloc(80);
    memset(a,0x6c,64);
    d=daimos_realloc(a,160);
    assert(d!=0 && d!=a);
    for(i=0;i<64;i++) assert(d[i]==0x6c);
    daimos_free(d); daimos_free(b);
    /* A freed neighbor abutting brk permits growth without moving. */
    a=daimos_malloc(80); b=daimos_malloc(96);
    memset(a,0x27,80);
    daimos_free(b);
    d=daimos_realloc(a,240);
    assert(d==a);
    for(i=0;i<80;i++) assert(a[i]==0x27);
    daimos_free(a);
    return 0;
}
'''
# For host mock, heap address bounds are all host pointers; preserve the
# allocator's real control flow and physical neighbor pointer arithmetic.
pathlib.Path(sys.argv[2]).write_text(pre+part+post)
PY
${HOST_CC:-cc} -std=c99 -O2 -Wall -Wextra -fno-builtin "$work/allocator.c" -o "$work/test"
"$work/test"
echo 'PASS: realloc adjacent free, top growth, shrink and coalescing'
