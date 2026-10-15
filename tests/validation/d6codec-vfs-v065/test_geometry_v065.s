/* v065: reject null destination and 18-bit output-span overflow before VFS. */
.text
.globl main
.globl d6codec_vfs_v062
.globl vfs_read_words
main:
 movei 1,1
 movei 2,0
 movei 3,2
 move 4,[2,,0777777]
 pushj 17,d6codec_vfs_v062
 camn 1,[-1]
 jrst check_null
 jrst fail
check_null:
 movei 1,1
 movei 2,0
 movei 3,2
 move 4,[2,,0]
 pushj 17,d6codec_vfs_v062
 camn 1,[-1]
 jrst pass
 jrst fail
pass:
 setz 1,
 popj 17,
fail:
 movei 1,1
 popj 17,
vfs_read_words:
 ; Reject all calls: no VFS I/O is permitted for invalid geometry.
 movei 1,17
 movem 1,unexpected_read
 seto 1,
 popj 17,
.bss
.globl unexpected_read
unexpected_read: .block 1
.globl __test_exit
__test_exit: .block 1
