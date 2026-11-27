/* Physical directory lifecycle: sparse PIPE restore/EXEC and stopped
 * user-mode foreign TERM. No privileged memory access or test hooks. */
#include "dsys.h"
#include "proc.h"

#define CHILDREN 12U
#define WORDS 04000U
#define EXIT_OLD 057U
#define EXIT_NEW 056U
#define S6(c) (((kword_t)(c)-040UL)&077UL)
#define SIX(a,b,c,d,e,f) ((S6(a)<<30)|(S6(b)<<24)|(S6(c)<<18)|(S6(d)<<12)|(S6(e)<<6)|S6(f))

static volatile kword_t data[WORDS];
static kword_t init_path[]={12UL,SIX('/','S','Y','S','T','E'),SIX('M','/','I','N','I','T')};
static kword_t comp_path[]={12UL,SIX('/','S','Y','S','T','E'),SIX('M','/','C','O','M','P')};
static kword_t post_path[]={12UL,SIX('/','S','Y','S','T','E'),SIX('M','/','P','O','S','T')};

static void mark(int c)
{
        (void)dsys_writechar(1,c);
}
static void fail(int c)
{
        mark('!'); mark(c); (void)dsys_exit(070);
}
static int pipe_pair(int *r,int *w)
{
        kword_t p=dsys_pipe();
        if(p==~0UL) return -1;
        *r=(int)(p>>18); *w=(int)(p&0777777UL);
        return *r<16 && *w<16 && *r!=*w ? 0:-1;
}
static void check_data(void)
{
        unsigned int i;
        if(data[0]!=012345670123UL || data[WORDS-1]!=076543210765UL) fail('D');
        for(i=1;i<WORDS-1;++i)
                if(data[i]!=(i%0100U==0U?(kword_t)i:0UL)) fail('d');
}
static int spawn(int fd,unsigned int marked,int role)
{
        kword_t block[17];
        kword_t *path=marked?comp_path:init_path;
        struct sys_run_v2 *r=(struct sys_run_v2 *)block;
        unsigned int i;
        for(i=0;i<17;++i) block[i]=0;
        r->version_words=SYS_RUN_HEADER(SYS_RUN_VERSION_2,17);
        r->fdmap_count=3; r->argc=2;
        for(i=0;i<3;++i) {
                block[6+i]=path[i]; block[9+i]=path[i];
        }
        block[12]=1; block[13]=S6(role)<<30;
        block[14]=SYS_RUN_FD_MAP(0,fd);
        block[15]=SYS_RUN_FD_MAP(1,1);
        block[16]=SYS_RUN_FD_MAP(2,2);
        return dsys_run(r);
}
static void replace(void)
{
        kword_t block[9];
        unsigned int i;
        struct sys_exec_v1 *e=(struct sys_exec_v1 *)block;
        e->version_words=SYS_RUN_HEADER(SYS_EXEC_VERSION_1,9);
        e->argc=1; e->envc=0;
        for(i=0;i<3;++i) {
                block[3+i]=post_path[i]; block[6+i]=post_path[i];
        }
        mark('E');
        (void)dsys_exec(e);
        fail('e'); /* A successful EXEC cannot return here. */
}
static void wait_exact(int pid,unsigned int kind,unsigned int value)
{
        kword_t status=0;
        if(dsys_wait((unsigned int)pid,&status,0)!=pid ||
            SYS_WAIT_STATUS_KIND(status)!=kind ||
            SYS_WAIT_STATUS_VALUE(status)!=value) fail('W');
}
static void wait_state(int pid,unsigned int state)
{
        unsigned int i;
        struct sys_procinfo p;
        for(i=0;i<020000U;++i) {
                if(dsys_procinfo((unsigned int)pid,&p)==0 && p.state==state)
                        return;
                if(dsys_sleep(1)!=0) fail('s');
        }
        fail('S');
}
int main(int argc,kword_t **argv)
{
        int r,w,ready_r,ready_w,pid[CHILDREN],role;
        unsigned int i,n;
        kword_t token=012345UL;
        for(i=0;i<WORDS;i+=0100U) data[i]=i;
        data[0]=012345670123UL; data[WORDS-1]=076543210765UL;
        if(argc>1) {
                role=(int)((argv[1][1]>>30)&077UL)+040;
                if(role=='S') {
                        if(dsys_write_words(0,&token,1)!=1 || dsys_close(0)!=0) fail('h');
                        /* Only user instructions after the readiness signal. */
                        for(;;) data[0100]++;
                }
                if(role!='P' && role!='E') fail('r');
                if(dsys_read_words(0,&token,1)!=0) fail('R');
                check_data();
                mark('w');
                if(role=='E') replace();
                (void)dsys_exit(EXIT_OLD);
                return EXIT_OLD;
        }
        if(pipe_pair(&r,&w) || pipe_pair(&ready_r,&ready_w)) fail('p');
        for(i=0;i<CHILDREN;++i) {
                role=i==0?'P':i==1?'E':'S';
                pid[i]=spawn(i<2?r:ready_w,i!=0,role);
                if(pid[i]<=1) break;
                if(i<2) wait_state(pid[i],PROC_SLEEP);
                else {
                        if(dsys_read_words(ready_r,&token,1)!=1 || token!=012345UL) fail('H');
                        /* Ensure the readiness syscall and close have returned
                         * before a clock saves the spinning user context. */
                        if(dsys_sleep(020U)!=0) fail('t');
                        if(dsys_procctl(SYS_PROCCTL_EVENT_PID,
                            SYS_EVENT_ARG(pid[i],SYS_EVENT_TSTP))!=0) fail('T');
                        wait_state(pid[i],PROC_STOP);
                        wait_exact(pid[i],SYS_WAIT_STOPPED,SYS_EVENT_TSTP);
                }
                mark('a');
        }
        n=i;
        if(n<4) fail('n');
        if(dsys_close(r)||dsys_close(ready_r)||dsys_close(ready_w)) fail('c');
        mark('x'); mark('['); mark('B');
        /* Foreign TERM must retire stopped nonresident owners directly. */
        for(i=2;i<n;++i) {
                if(dsys_procctl(SYS_PROCCTL_EVENT_PID,
                    SYS_EVENT_ARG(pid[i],SYS_EVENT_TERM))!=0) fail('K');
                wait_exact(pid[i],SYS_WAIT_EXITED,SYS_WAIT_EVENT_FLAG|SYS_EVENT_TERM);
                mark('k');
        }
        mark('L');
        if(dsys_close(w)!=0) fail('l');
        wait_exact(pid[0],SYS_WAIT_EXITED,EXIT_OLD);
        wait_exact(pid[1],SYS_WAIT_EXITED,EXIT_NEW);
        check_data();
        mark('Z');
        return 0;
}
