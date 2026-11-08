#!/usr/bin/env python3
"""Native PDP-6 VFS adapter acceptance from independent host golden DXR."""
import pathlib
import sys


def values(data):
    return [int(line.split()[-1], 8) for line in data.splitlines()
            if line.lstrip().startswith(".word")]


if len(sys.argv) != 3:
    raise SystemExit("usage: generate-v1366.py NATIVE_V1359_KCORE OUT_S")
text = pathlib.Path(sys.argv[1]).read_text()
source = values(text.split("source:\n", 1)[1].split("golden:\n", 1)[0])
encoded = values(text.split("golden:\n", 1)[1].split(".bss", 1)[0])
assert len(source) == 128 and 32 < len(encoded) <= 256
tail = [0o12345670123] * 20
code = """/* v1366 grouped codec runtime VFS: host golden KCORE DXR prefix.
 * VFS stub simulates short reads, EOF/error, malformed control,
 * trusted immutable tail and exact-length trailing input rejection.
 */
.text
.globl main
.globl d6codec_decode_vfs_v1366
.globl d6codec_decode_buffer_v1366
.globl vfs_read_words
main:
 movei 10,0101
 movei 11,0102
 movei 12,0103
 movei 13,0104
 movei 14,0105
 movei 15,0106
 movei 16,0107
 ; Direct-buffer, exact framing.
 movei 2,compressed
 movei 3,0%o
 movei 4,decoded
 hrli 4,0200
 pushj 17,d6codec_decode_buffer_v1366
 jumpn 1,fail1
 pushj 17,verify_output
 jumpn 1,fail1
 pushj 17,verify_ac
 jumpn 1,fail1
 ; Vnode 1: exact bounded VFS length and 32-word windows.
 movei 1,1
 setz 2,
 movei 3,0%o
 movei 4,decoded
 hrli 4,0200
 pushj 17,d6codec_decode_vfs_v1366
 jumpn 1,fail2
 pushj 17,verify_output
 jumpn 1,fail2
 ; Vnode 2: provider returns at most 7 input words per refill.
 movei 1,2
 setz 2,
 movei 3,0%o
 movei 4,decoded
 hrli 4,0200
 pushj 17,d6codec_decode_vfs_v1366
 jumpn 1,fail3
 pushj 17,verify_output
 jumpn 1,fail3
 ; Vnode 3: trusted immutable backing has 20 extra input words.
 ; The output boundary, not a compressed size, terminates decoding.
 movei 1,3
 setz 2,
 setz 3,
 movei 4,decoded
 hrli 4,0200
 pushj 17,d6codec_decode_vfs_v1366
 jumpn 1,fail4
 pushj 17,verify_output
 jumpn 1,fail4
 ; Vnode 4: premature EOF/provider error must be refused.
 movei 1,4
 setz 2,
 movei 3,0%o
 movei 4,decoded
 hrli 4,0200
 pushj 17,d6codec_decode_vfs_v1366
 camn 1,[-1]
 jrst check5
 jrst fail5
check5:
 ; Vnode 5: invalid first control word must be refused.
 move 0,[012345670123]
 movem 0,decoded
 movei 1,5
 setz 2,
 movei 3,0%o
 movei 4,decoded
 hrli 4,0200
 pushj 17,d6codec_decode_vfs_v1366
 camn 1,[-1]
 jrst verify5
 jrst fail6
verify5:
 move 0,decoded
 came 0,[012345670123]
 jrst fail6
 ; Vnode 6: declared compressed bound includes an extra tail.
 movei 1,6
 setz 2,
 movei 3,0%o
 movei 4,decoded
 hrli 4,0200
 pushj 17,d6codec_decode_vfs_v1366
 camn 1,[-1]
 jrst check7
 jrst fail7
check7:
 ; Direct-buffer truncated source must be rejected.
 movei 2,compressed
 movei 3,0%o
 movei 4,decoded
 hrli 4,0200
 pushj 17,d6codec_decode_buffer_v1366
 camn 1,[-1]
 jrst check8
 jrst fail8
check8:
 ; Direct-buffer/source overlap is invalid.
 movei 2,compressed
 movei 3,0%o
 movei 4,compressed
 hrli 4,0200
 pushj 17,d6codec_decode_buffer_v1366
 camn 1,[-1]
 jrst check9
 jrst fail9
check9:
 ; Trusted/unbounded direct buffers must never be accepted.
 movei 2,compressed
 setz 3,
 movei 4,decoded
 hrli 4,0200
 pushj 17,d6codec_decode_buffer_v1366
 camn 1,[-1]
 jrst check10
 jrst fail10
check10:
 pushj 17,verify_ac
 jumpn 1,fail11
 ; Negative exact length is invalid, not an implicit trusted mode.
 movei 1,1
 setz 2,
 seto 3,
 movei 4,decoded
 hrli 4,0200
 pushj 17,d6codec_decode_vfs_v1366
 camn 1,[-1]
 jrst check12
 jrst fail12
check12:
 ; 18-bit max+1 cannot be represented in the compressed word count.
 movei 1,1
 setz 2,
 move 3,[01000000]
 movei 4,decoded
 hrli 4,0200
 pushj 17,d6codec_decode_vfs_v1366
 camn 1,[-1]
 jrst check13
 jrst fail13
check13:
 ; Destination may not alias the saved registers/refill stack frame.
 movei 1,1
 setz 2,
 movei 3,0%o
 hrrz 4,17
 addi 4,020
 hrli 4,0200
 pushj 17,d6codec_decode_vfs_v1366
 camn 1,[-1]
 jrst check14
 jrst fail14
check14:
 ; A direct input pointer into the future frame must be refused.
 hrrz 2,17
 addi 2,020
 movei 3,2
 movei 4,decoded
 hrli 4,0200
 pushj 17,d6codec_decode_buffer_v1366
 camn 1,[-1]
 jrst check15
 jrst fail15
check15:
 pushj 17,verify_ac
 jumpn 1,fail16
 setz 1,
 popj 17,

verify_ac:
 caie 10,0101
 jrst ac_bad
 caie 11,0102
 jrst ac_bad
 caie 12,0103
 jrst ac_bad
 caie 13,0104
 jrst ac_bad
 caie 14,0105
 jrst ac_bad
 caie 15,0106
 jrst ac_bad
 caie 16,0107
 jrst ac_bad
 setz 1,
 popj 17,
ac_bad:
 seto 1,
 popj 17,

verify_output:
 movei 5,0
verify_loop:
 move 6,source(5)
 came 6,decoded(5)
 jrst verify_bad
 aoj 5,
 caige 5,0200
 jrst verify_loop
 setz 1,
 popj 17,
verify_bad:
 seto 1,
 popj 17,

fail1: movei 1,1
 popj 17,
fail2: movei 1,2
 popj 17,
fail3: movei 1,3
 popj 17,
fail4: movei 1,4
 popj 17,
fail5: movei 1,5
 popj 17,
fail6: movei 1,6
 popj 17,
fail7: movei 1,7
 popj 17,
fail8: movei 1,010
 popj 17,
fail9: movei 1,011
 popj 17,
fail10: movei 1,012
 popj 17,
fail11: movei 1,013
 popj 17,
fail12: movei 1,014
 popj 17,
fail13: movei 1,015
 popj 17,
fail14: movei 1,016
 popj 17,
fail15: movei 1,017
 popj 17,
fail16: movei 1,020
 popj 17,

/* Fake VFS: AC1 vnode behavior selector, AC2 file offset,
 * AC3 output buffer, AC4 requested maximum input words.
 * Return AC1 exact words read or -1 for provider error.
 * Preserve AC10..16, like the kernel's normal ABI.
 */
vfs_read_words:
 move 5,1
 movei 7,0%o
 caie 5,3
 jrst provider_maybe6
 movei 7,0%o
 jrst provider_maybe4
provider_maybe6:
 caie 5,6
 jrst provider_maybe4
 movei 7,0%o
provider_maybe4:
 caie 5,4
 jrst provider_len_ready
 movei 7,0%o
provider_len_ready:
 move 6,7
 sub 6,2
 jumple 6,provider_fail
 camle 4,6
 move 4,6
 caie 5,2
 jrst provider_copy_prepare
 caile 4,7
 movei 4,7
provider_copy_prepare:
 move 1,4
 movei 6,compressed
 add 6,2
 move 7,3
provider_copy:
 move 0,0(6)
 caie 5,5
 jrst provider_store
 jumpn 2,provider_store
 setz 0,
provider_store:
 movem 0,0(7)
 aoj 2,
 aoj 6,
 aoj 7,
 sojg 4,provider_copy
 popj 17,
provider_fail:
 seto 1,
 popj 17,

.data
source:
""" % (len(encoded), len(encoded), len(encoded), len(encoded),
       len(encoded), len(encoded)+20, len(encoded)-1, len(encoded),
       len(encoded), len(encoded)+20, len(encoded)+20, len(encoded),
       len(encoded)//2)
code += "".join(" .word 0%o\n" % w for w in source)
code += "compressed:\n"
code += "".join(" .word 0%o\n" % w for w in encoded + tail)
code += ".bss\ndecoded: .block 0200\n"
code += ".globl __test_exit\n__test_exit: .block 1\n"
pathlib.Path(sys.argv[2]).write_text(code)
