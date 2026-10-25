/* Native minimal process namespace check: no RUN, no fork, no scheduler child. */
#include "dsys.h"
#include "../test_sixbit.h"
static kword_t proc_path[] = { 5UL, TEST_SIX6('/','P','R','O','C',' ') };
static kword_t state_path[] = { 13UL, TEST_SIX6('/','P','R','O','C','/'), TEST_SIX6('1','/','S','T','A','T'), TEST_SIX6('E',' ',' ',' ',' ',' ') };
static kword_t domains_path[] = {16UL,
 TEST_SIX6('/','M','O','N','I','T'), TEST_SIX6('O','R','/','D','O','M'),
 TEST_SIX6('A','I','N','S',' ',' ') };
static void fail(int ch) { (void)dsys_writechar(1,'!'); (void)dsys_writechar(1,ch); (void)dsys_exit(1); }
int main(void) {
 struct vfs_stat st;
 kword_t data[8];
 int fd, count;
 (void)dsys_writechar(1,'<');
 if (dsys_stat(proc_path,&st) != 0) fail('1');
 (void)dsys_writechar(1,'A');
 if (dsys_stat(state_path,&st) != 0) fail('2');
 (void)dsys_writechar(1,'B');
 fd=dsys_open(state_path,SYS_O_RDONLY);
 if (fd<3) fail('3');
 (void)dsys_writechar(1,'C');
 count=dsys_read_words(fd,data,8U);
 if (count <= 0 || (data[0] >> 30U) != 1UL) fail('4');
 if (dsys_close(fd) != 0) fail('5');
 if (dsys_stat(domains_path,&st) != 0) fail('6');
 (void)dsys_writechar(1,'D');
 fd=dsys_open(domains_path,SYS_O_RDONLY);
 if (fd<3) fail('7');
 (void)dsys_writechar(1,'E');
 { struct vfs_dirent ent; count=dsys_dirread(fd,&ent); if(count < 0) fail('8'); }
 (void)dsys_writechar(1,'F');
 if (dsys_close(fd) != 0) fail('9');
 (void)dsys_writechar(1,'H');
 (void)dsys_exit(0);
 return 0;
}
