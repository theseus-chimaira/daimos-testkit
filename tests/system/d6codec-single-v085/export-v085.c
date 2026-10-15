/* Read-only D6FS word exporter for regression tests. Reuse fsck geometry,
 * remapping, FCB decoding, and directory traversal instead of duplicating.
 */
#define main d6fsck_original_main
#include "d6fsck.c"
#undef main

static int named(const uint64_t entry[6], const char *name)
{
    unsigned i, j;
    size_t length = strlen(name);
    if (length > 24) return 0;
    for (i = 0; i < 24; ++i) {
        unsigned v = (unsigned)((entry[i/6] >> (30-6*(i%6))) & 077U);
        unsigned want = i < length ? ((unsigned char)name[i] - 32U) : 0U;
        if (v != want) return 0;
    }
    for (j = 4; j < 6; ++j) (void)entry[j];
    return 1;
}

int main(int argc, char **argv)
{
    struct super_info a, b, *s;
    uint64_t ba[BLOCK_WORDS], bb[BLOCK_WORDS], *fcbs;
    unsigned sa, sb, i, blk, current;
    int av, bv;
    const char *path;
    FILE *out;
    if (argc != 4) {
        fprintf(stderr, "usage: export-v085 DISKDIR /ABS/PATH OUTPUT\n");
        return 2;
    }
    path = argv[2];
    open_members(argv[1], 1, &sa, &sb);
    if (read_logical(sa,ba) || read_logical(sb,bb)) die("cannot read superblocks");
    av = super_decode(ba,total_blocks(),&a) == 0;
    bv = super_decode(bb,total_blocks(),&b) == 0;
    if (!av && !bv) die("invalid superblocks");
    s = !bv ? &a : (!av ? &b : sequence_newer(b.sequence,a.sequence) ? &b : &a);
    fcbs = calloc((size_t)s->fcb_count * FCB_WORDS,sizeof(*fcbs));
    if (!fcbs) die("out of memory");
    for (blk=0; blk < (s->fcb_count*FCB_WORDS+BLOCK_WORDS-1)/BLOCK_WORDS; ++blk) {
        uint64_t data[BLOCK_WORDS]; size_t offset=(size_t)blk*BLOCK_WORDS, total=(size_t)s->fcb_count*FCB_WORDS;
        size_t n = total-offset < BLOCK_WORDS ? total-offset : BLOCK_WORDS;
        if (read_logical(s->fcb_start+blk,data)) die("cannot read FCB");
        memcpy(fcbs+offset,data,n*sizeof(*data));
    }
    current=s->root;
    if (*path!='/' || !path[1]) die("invalid path");
    ++path;
    while (*path) {
        char component[25]; size_t length=0; int found=0;
        const uint64_t *f;
        while (*path && *path!='/') {
            if (length>=24) die("path component too long");
            component[length++]=*path++;
        }
        component[length]=0;
        if (*path=='/') ++path;
        f=fcbs+(size_t)current*FCB_WORDS;
        if ((f[0] >> 33) != D6FS_TYPE_DIR) die("not a directory");
        for (i=0; (uint64_t)i+6<=f[2]; i+=6) {
            uint64_t entry[6]; unsigned j, child;
            for (j=0;j<6;++j)
                if (read_file_word(s,fcbs,current,i+j,&entry[j])) die("cannot read directory");
            if (!named(entry,component)) continue;
            child=(unsigned)((entry[5]>>18)&HALF_MASK);
            if (child>=s->fcb_count) die("invalid directory index");
            current=child; found=1; break;
        }
        if (!found) die("path not found");
    }
    if ((fcbs[(size_t)current*FCB_WORDS] >> 33)!=D6FS_TYPE_REG) die("not a regular file");
    out=fopen(argv[3],"wb");
    if (!out) die("cannot create export");
    for (uint64_t off=0;off<fcbs[(size_t)current*FCB_WORDS+2];++off) {
        uint64_t value; unsigned char raw[8];
        if (read_file_word(s,fcbs,current,off,&value)) die("cannot read file data");
        put64le(raw,value);
        if (fwrite(raw,1,8,out)!=8) die("cannot write export");
    }
    if (fclose(out)) die("cannot close export");
    free(fcbs); close_members();
    return 0;
}
