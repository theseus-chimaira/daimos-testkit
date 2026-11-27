/* Run from genuine DSH. The shell blocks in WAIT while this process
 * starts an unmarked large child. Hold that child on a pipe until the
 * host observes the actual shell's packed or resident owner. */
#include "dsys.h"
#define S6(c) (((kword_t)(c)-040UL)&077UL)
#define SIX(a,b,c,d,e,f) ((S6(a)<<30)|(S6(b)<<24)|(S6(c)<<18)|(S6(d)<<12)|(S6(e)<<6)|S6(f))
static kword_t path[]={17UL,SIX('/','S','Y','S','T','E'),SIX('M','/','E','X','E','C'),SIX('/','K','1','5','H',' ')};
static void say(const char *s)
{
        while(*s) (void)dsys_writechar(1,*s++);
}
int main(void)
{
        kword_t p=dsys_pipe(), status=0UL, block[17];
        struct sys_run_v2 *r=(struct sys_run_v2 *)block;
        int rd,wr,pid,ch;
        unsigned int i;
        if(p==~0UL) { say("K15PIPEFAIL\r\n"); return 1; }
        rd=(int)(p>>18); wr=(int)(p&0777777UL);
        /* Give the real foreground shell time to enter WAIT. */
        if(dsys_sleep(30U)!=0) return 2;
        for(i=0U;i<17U;++i) block[i]=0UL;
        r->version_words=SYS_RUN_HEADER(SYS_RUN_VERSION_2,17U);
        r->fdmap_count=3U; r->argc=1U;
        for(i=0U;i<4U;++i) block[6U+i]=block[10U+i]=path[i];
        block[14]=SYS_RUN_FD_MAP(0,rd);
        block[15]=SYS_RUN_FD_MAP(1,1);
        block[16]=SYS_RUN_FD_MAP(2,2);
        pid=dsys_run(r);
        if(pid<0) { say("K15RUNFAIL\r\n"); return 3; }
        if(dsys_close(rd)!=0) return 4;
        say("K15HELD\r\n");
        do { ch=dsys_readchar(0); } while(ch==-2 || ch==-3);
        if(ch!='X') return 5;
        if(dsys_close(wr)!=0) return 6;
        if(dsys_wait((unsigned int)pid,&status,0U)!=pid ||
            SYS_WAIT_STATUS_KIND(status)!=SYS_WAIT_EXITED ||
            SYS_WAIT_STATUS_VALUE(status)!=57U) return 7;
        say("K15REAPED\r\n");
        return 0;
}
