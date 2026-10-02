        .text
        .globl  vfs_read_words

; Standalone D6LZ decoder tests do not exercise d6lz36_decode_vfs(), but the
; target decoder object also exports that entry point.  Keep the unit test
; independent of the full VFS by satisfying its link-time dependency here.
vfs_read_words:
        movei   1,-1
        popj    17,
