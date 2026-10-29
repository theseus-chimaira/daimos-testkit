#!/bin/sh
# Exercise the production region translator and read/write path on the host.
set -eu
: "${DAIMOS_REPO:?}"
export TMPDIR=${TMPDIR:-$HOME/tmp}
work=$(mktemp -d "$TMPDIR/daimos-auxstore-region-v657.XXXXXX")
trap 'rm -rf "$work"' EXIT HUP INT TERM
cat > "$work/test.c" <<'EOF'
#include <stdint.h>
#include <stdio.h>
typedef uint64_t kword_t;
#define AUXSTORE_KIND_NONE 0U
#define AUXSTORE_KIND_DSK 1U
#define AUXSTORE_KIND_DRM 2U
#define AUXSTORE_REGION_BACKSTORE 1U
#define AUXSTORE_REGION_LOGSTORE 2U
#define AUXSTORE_REGION_CACHE 3U
static unsigned int auxstore_kind=1U,auxstore_unit=0U;
static kword_t auxstore_backstore_start=0100,auxstore_backstore_blocks=4;
static kword_t auxstore_logstore_start=0200,auxstore_logstore_blocks=2;
static kword_t auxstore_cache_start=0300,auxstore_cache_blocks=1;
static kword_t last_block;
static unsigned int reads,writes;
static int auxstore_phys_read(unsigned int k,unsigned int u,kword_t b,kword_t *p)
{ if(k!=1U||u!=0U)return -1; last_block=b; reads++; *p=b; return 0; }
static int auxstore_phys_write(unsigned int k,unsigned int u,kword_t b,const kword_t *p)
{ if(k!=1U||u!=0U||!p)return -1; last_block=b; writes++; return 0; }
EOF
# Reuse the actual implementation, rather than testing an independently
# reimplemented mock translator.
sed -n '/^static int$/,$p' "$DAIMOS_REPO/system/kernel/storage/auxstore_boot.c" | \
    sed -n '/^auxstore_region_block(/,$p' | sed '1i static int' \
    >> "$work/test.c"
cat >> "$work/test.c" <<'EOF'
int main(void)
{
 kword_t v=0, before;
 if(auxstore_boot_region_read(AUXSTORE_REGION_LOGSTORE,1,&v)||v!=0201) return 1;
 if(auxstore_boot_region_write(AUXSTORE_REGION_BACKSTORE,3,&v)||last_block!=0103) return 2;
 if(auxstore_boot_region_read(AUXSTORE_REGION_CACHE,0,&v)||v!=0300) return 3;
 before=reads+writes;
 if(!auxstore_boot_region_read(AUXSTORE_REGION_LOGSTORE,2,&v)||
    !auxstore_boot_region_write(AUXSTORE_REGION_BACKSTORE,4,&v)||
    !auxstore_boot_region_read(AUXSTORE_REGION_CACHE,1,&v)||
    !auxstore_boot_region_read(99,0,&v)||
    !auxstore_boot_region_write(AUXSTORE_REGION_CACHE,0,0)||
    before!=reads+writes) return 4;
 auxstore_kind=AUXSTORE_KIND_NONE;
 if(!auxstore_boot_region_read(AUXSTORE_REGION_LOGSTORE,0,&v)) return 5;
 puts("daimos-auxstore-region-v657: PASS");
 return 0;
}
EOF
${CC:-cc} -std=c99 -Wall -Wextra -Werror -o "$work/test" "$work/test.c"
"$work/test"
