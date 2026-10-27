#!/bin/sh
# Exercise the actual KINIT AUXST1 range validator with malformed descriptors.
set -eu
: "${DAIMOS_REPO:?}"
: "${TMPDIR:?}"
work="$TMPDIR/daimos-auxstore-d6fs-overlap-v507-$$"
mkdir -p "$work"
trap 'rm -rf "$work"' EXIT HUP INT TERM
awk '/^auxstore_overlap\(/ {print "static int"; found=1} found {if (/^auxstore_boot_discover\(/) exit; print}' \
    "$DAIMOS_REPO/system/kernel/storage/auxstore_boot.c" | sed '$d' > "$work/actual.c"
cat > "$work/test.c" <<'SRC'
#include <stdio.h>
#include <string.h>
typedef unsigned long kword_t;
#define AUXSTORE_HALF_MASK 0777777UL
#define AUXSTORE_KIND_DRM 2U
#define AUXSTORE_KIND_DSK 1U
#define AUXSTORE_DESC_MAGIC 0U
#define AUXSTORE_DESC_VERSION 1U
#define AUXSTORE_DESC_BACKSTORE 2U
#define AUXSTORE_DESC_LOGSTORE 3U
#define AUXSTORE_DESC_CACHE 4U
#define AUXSTORE_DESC_D6FS 5U
#define AUXSTORE_DESC_D6SUPER 6U
#define AUXSTORE_MAGIC 0416570636421UL
#define AUXSTORE_VERSION 1UL
#define DRM236_BLOCKS_PER_UNIT 020000U
#define DSK270_SECTORS_PER_UNIT 0100000U
static kword_t buffer[128];
static kword_t *fs_block_workspace = buffer;
static unsigned int auxstore_kind, auxstore_unit;
static kword_t auxstore_backstore_start, auxstore_backstore_blocks;
static kword_t auxstore_logstore_start, auxstore_logstore_blocks;
static kword_t auxstore_cache_start, auxstore_cache_blocks;
static int auxstore_phys_read(unsigned int kind, unsigned int unit,
    kword_t sector, kword_t *buf)
{ (void)kind; (void)unit; (void)sector; (void)buf; return 0; }
#include "actual.c"
static kword_t pair(unsigned int a, unsigned int n)
{ return ((kword_t)a << 18U) | n; }
static void init(void)
{
    memset(buffer, 0, sizeof(buffer));
    buffer[0] = AUXSTORE_MAGIC;
    buffer[1] = AUXSTORE_VERSION;
    buffer[2] = pair(03000, 01000);
    buffer[3] = pair(05000, 0100);
    buffer[4] = pair(06000, 0100);
    buffer[5] = pair(1, 02000);
    buffer[6] = pair(0, 1);
}
int main(void)
{
    int errors=0;
#define CHECK(expect) do { if ((auxstore_try(AUXSTORE_KIND_DSK,0)==0)!=(expect)) ++errors; } while(0)
    init(); CHECK(1);
    buffer[5]=pair(02500,02000); CHECK(0); /* overlap BACKSTORE */
    init(); buffer[5]=pair(04700,0400); CHECK(0); /* overlap LOG */
    init(); buffer[5]=pair(05700,0400); CHECK(0); /* overlap CACHE */
    init(); buffer[6]=pair(02000,1); CHECK(0); /* out-of-range super */
    init(); buffer[6]=pair(1,1); CHECK(0); /* duplicate supers */
    init(); buffer[5]=0; CHECK(0); /* missing partition but supers set */
    init(); buffer[5]=0; buffer[6]=0; CHECK(1); /* no D6FS is valid */
    init(); buffer[5]=pair(077700,02000); CHECK(0); /* beyond medium */
    if (errors) fprintf(stderr,"AUXST1 D6FS validation: %d failures\n",errors);
    else puts("daimos-auxstore-d6fs-overlap-v507: PASS");
    return errors != 0;
}
SRC
${CC:-cc} -std=c99 -O2 -Wall -Wextra -Werror -I"$work" "$work/test.c" -o "$work/test"
"$work/test"
