#!/bin/sh
# Exercise the actual DAIMOS C RM implementation against a minimal fake VFS.
set -eu
: "${DAIMOS_REPO:?}"
export TMPDIR=${TMPDIR:-"$HOME/tmp"}
mkdir -p "$TMPDIR"
work=$(mktemp -d "$TMPDIR/daimos-rm-behavior-v1.XXXXXX")
trap 'rm -rf "$work"' EXIT HUP INT TERM
python3 - "$DAIMOS_REPO/userland/exec/commands.c" "$work/runner.c" <<'PY'
from pathlib import Path
import sys
src=Path(sys.argv[1]).read_text()
start=src.index('#if DAIMOS_CMD_PROGRAM == CMD_PROGRAM_RM\n')
end=src.index('\n#endif',start)+len('\n#endif')
block=src[start:end]
header=r'''
#include <assert.h>
#include <stdio.h>
#include <string.h>
#include <stddef.h>
#define DAIMOS_CMD_PROGRAM 5
#define CMD_PROGRAM_RM 5
#define U_PATH_WORDS 18U
#define U_ARG_WORDS 18U
#define VFS_NAME_WORDS 4U
#define VFS_NAME_MAX_CHARS 24U
#define VFS_TYPE_DIR 1U
#define VFS_TYPE_REG 2U
#define VFS_TYPE_SYMLINK 6U
#define VFS_TYPE_MOUNTSRC 5U
#define SYS_O_RDONLY 0U
typedef unsigned long long kword_t;
struct vfs_stat { unsigned int type; };
struct vfs_name { unsigned int chars; kword_t words[VFS_NAME_WORDS]; };
struct vfs_dirent { struct vfs_name name; unsigned int type; };
struct u_io { int err_fd; };
struct node { const char *path; unsigned int type; int alive; };
static struct node nodes[] = {
    {"BUILD", VFS_TYPE_DIR, 1},
    {"BUILD/ONE", VFS_TYPE_REG, 1},
    {"BUILD/SUB", VFS_TYPE_DIR, 1},
    {"BUILD/SUB/TWO", VFS_TYPE_REG, 1},
    {"BUILD/LINK", VFS_TYPE_SYMLINK, 1},
    {"OTHER", VFS_TYPE_REG, 1},
    {"LINKTOP", VFS_TYPE_SYMLINK, 1}
};
static int errors;
static unsigned int dircursor[101];
static void decode(const kword_t *s, char *dst) {
    unsigned int i;
    for (i = 0U; i < (unsigned int)s[0]; ++i)
        dst[i] = (char)(((s[1U+i/6U] >> (30U-(i%6U)*6U)) & 077U) + 040U);
    dst[s[0]] = 0;
}
static int u_s6_pack(kword_t *dst,unsigned int words,const char *src) {
    unsigned int i, len=(unsigned int)strlen(src);
    if (len>(words-1U)*6U) return -1;
    memset(dst,0,words*sizeof(*dst));dst[0]=len;
    for(i=0U;i<len;++i)dst[1U+i/6U]|=(kword_t)((unsigned int)src[i]-040U) << (30U-(i%6U)*6U);
    return 0;
}
static int u_s6_eq(const kword_t *s,const char *t) {
    char tmp[110];decode(s,tmp);return strcmp(tmp,t)==0;
}
static int u_s6_from_dirent(kword_t *dst,unsigned int words,const struct vfs_dirent *e) {
    unsigned int i;if(words<VFS_NAME_WORDS+1U)return -1;
    memset(dst,0,words*sizeof(*dst));dst[0]=e->name.chars;
    for(i=0U;i<VFS_NAME_WORDS;++i)dst[1U+i]=e->name.words[i];
    return 0;
}
static int find(const kword_t *p) {
    char name[110];unsigned int i;decode(p,name);
    for(i=0U;i<sizeof(nodes)/sizeof(nodes[0]);++i)
        if(nodes[i].alive&&strcmp(nodes[i].path,name)==0)return (int)i;
    return -1;
}
static int dsys_stat(kword_t *p,struct vfs_stat *st) {
    int i=find(p);if(i<0)return -1;
    st->type=nodes[i].type==VFS_TYPE_SYMLINK?VFS_TYPE_DIR:nodes[i].type;
    return 0;
}
static int dsys_open(kword_t *p,unsigned int flags) {
    int i=find(p);(void)flags;
    if(u_s6_eq(p,".")){dircursor[100]=0U;return 100;}
    if(i>=0&&nodes[i].type==VFS_TYPE_DIR){dircursor[i+1]=0U;return i+1;}
    return -1;
}
static int dsys_close(int fd) {(void)fd;return 0;}
static int dsys_dirread(int fd,struct vfs_dirent *e) {
    unsigned int i,n;const char *parent,*child,*slash,*base;
    if(fd<=0||(fd!=100&&(unsigned int)fd>sizeof(nodes)/sizeof(nodes[0])))return -1;
    parent=fd==100?"":nodes[fd-1].path;n=strlen(parent);
    for(i=dircursor[fd];i<sizeof(nodes)/sizeof(nodes[0]);++i) {
        if(!nodes[i].alive||(fd!=100&&i==(unsigned int)(fd-1)))continue;
        child=nodes[i].path;
        if(fd==100)base=child;
        else {
            if(strncmp(child,parent,n)!=0||child[n]!='/')continue;
            base=child+n+1;
        }
        slash=strchr(base,'/');if(slash!=NULL)continue;
        {kword_t name[U_ARG_WORDS];unsigned int j;
         if(u_s6_pack(name,U_ARG_WORDS,base)!=0)return -1;
         e->name.chars=(unsigned int)name[0];
         for(j=0U;j<VFS_NAME_WORDS;++j)e->name.words[j]=name[j+1U];}
        e->type=nodes[i].type;dircursor[fd]=i+1U;return 1;
    }
    return 0;
}
static int dsys_unlink(kword_t *p) {
    int i=find(p);if(i<0||nodes[i].type==VFS_TYPE_DIR)return -1;
    nodes[i].alive=0;return 0;
}
static int dsys_rmdir(kword_t *p) {
    int i=find(p);unsigned int j;size_t n;
    if(i<0||nodes[i].type!=VFS_TYPE_DIR)return -1;
    n=strlen(nodes[i].path);
    for(j=0U;j<sizeof(nodes)/sizeof(nodes[0]);++j)
        if(nodes[j].alive&&j!=(unsigned int)i&&
           strncmp(nodes[j].path,nodes[i].path,n)==0&&nodes[j].path[n]=='/')return -1;
    nodes[i].alive=0;return 0;
}
static int cmd_err(struct u_io *io,const char *name,kword_t *path) {
    (void)io;(void)name;(void)path;++errors;return 1;
}
'''
footer=r'''
static int invoke(const char *a,const char *b,const char *c) {
    kword_t aa[U_ARG_WORDS],bb[U_ARG_WORDS],cc[U_ARG_WORDS];
    kword_t *args[4];struct u_io io={2};int n=1;
    u_s6_pack(aa,U_ARG_WORDS,"RM");args[0]=aa;
    if(a){u_s6_pack(bb,U_ARG_WORDS,a);args[n++]=bb;}
    if(b){u_s6_pack(cc,U_ARG_WORDS,b);args[n++]=cc;}
    if(c){static kword_t dd[U_ARG_WORDS];u_s6_pack(dd,U_ARG_WORDS,c);args[n++]=dd;}
    return cmd_rm(n,args,&io);
}
int main(void) {
    unsigned int i;
    assert(invoke("-R","/",NULL)!=0);
    assert(invoke("-R","BUILD/..",NULL)!=0);
    assert(invoke("-R","./BUILD",NULL)!=0);
    assert(invoke("-R","BUILD/../OTHER",NULL)!=0);
    assert(invoke(NULL,"BUILD",NULL)!=0);
    for(i=0U;i<sizeof(nodes)/sizeof(nodes[0]);++i)assert(nodes[i].alive);
    assert(invoke("-R","LINKTOP",NULL)==0);
    assert(!nodes[6].alive && nodes[0].alive);
    assert(invoke("-R","BUILD",NULL)==0);
    for(i=0U;i<5U;++i)assert(!nodes[i].alive);
    assert(nodes[5].alive);
    assert(invoke(NULL,"OTHER",NULL)==0);
    assert(!nodes[5].alive);
    assert(invoke("-R","-F","BUILD")==0);
    printf("PASS: recursive RM, symlink safety, protected anchors, ordinary unlink, -F\n");
    return 0;
}
'''
Path(sys.argv[2]).write_text(header+block+'\n'+footer)
PY
${CC:-cc} -std=c99 -Wall -Wextra -Werror -o "$work/runner" "$work/runner.c"
"$work/runner"
