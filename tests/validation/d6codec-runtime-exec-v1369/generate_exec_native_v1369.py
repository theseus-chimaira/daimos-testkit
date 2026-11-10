#!/usr/bin/env python3
"""Generate native EXEC tests from a real compiled DXR and grouped DXR2."""
import pathlib
import sys

import grouped_dxr_v1369 as codec


def literal(words):
    return "".join("        .word 0%o\n" % word for word in words)


def generate(source, compressed, destination):
    original = codec.load(source)
    grouped = codec.load(compressed)
    header, image, reloc, text_words = codec.unpack_original(original)
    if grouped[0] != original[0] or (grouped[1] & ~codec.COMPRESSED) != original[1]:
        raise ValueError("original/grouped executable header mismatch")
    if codec.validate_grouped(grouped) != original[header:header + image]:
        raise ValueError("grouped test executable differs from original")
    if grouped[-reloc:] != original[-reloc:]:
        raise ValueError("grouped relocation bitmap differs from original")
    if image > 0o4000:
        raise ValueError("native EXEC fixture image exceeds test memory budget")
    # The actual compiled marker function must be entry 020 and return 012345.
    executable = pathlib.Path(source).name.startswith("marker-")
    if executable and (image != 2 or original[0] & codec.HALF != 0):
        raise ValueError("unexpected compiled marker DXR layout")

    filelen = len(grouped)
    compressed_len = filelen - reloc - 3
    source_words = original[header:header + image]
    if not 0 < compressed_len <= codec.HALF:
        raise ValueError("invalid compressed count for native fixture")
    source_label = "expected_image_v1369"
    file_label = "actual_grouped_dxr_v1369"
    code = """/* v1369: native PDP-6 real EXEC loader + grouped DXR2 file.
 * Calls the ACTUAL exec_load_process, not a reconstructed code path.
 * VFS/provider and VM allocation are local deterministic substitutes.
 * Test cases: success, PURE success, malformed token and provider EOF.
 */
        .text
        .globl main
        .globl exec_load_process
        .globl d6lz36_decode_vfs
        .globl file_lookup_path
        .globl file_check_access
        .globl file_check_root
        .globl vfs_stat
        .globl vfs_read_words
        .globl vm_space_create
        .globl vm_space_load_file
        .globl vm_space_destroy
        .globl proc_swap_attach
        .globl proc_rt_owner
        .globl proc_swap_reload_pure
        .globl proc_swap_unpack_backing

main:
        setzm mode_v1369
        pushj 17,reset_v1369
        pushj 17,load_v1369
        jumpn 1,fail1
        pushj 17,verify_image_v1369
        jumpn 1,fail2
        pushj 17,verify_commit_v1369
        jumpn 1,fail3
"""
    if executable:
        code += """        ; Execute the actual two compiled PDP-6 instructions after
        ; the EXEC loader populated the relocated physical VM image.
        pushj 17,vmspace_v1369+020
        caie 1,012345
        jrst fail4
"""
    code += """        movei 0,1
        movem 0,mode_v1369
        pushj 17,reset_v1369
        pushj 17,load_v1369
        jumpn 1,fail5
        pushj 17,verify_image_v1369
        jumpn 1,fail6
        pushj 17,verify_commit_v1369
        jumpn 1,fail7
        move 0,attach_pure_v1369
        caie 0,1
        jrst fail8

        ; Evict executable text and call the *real* PURE reload leaf.
        movei 5,0
wipe_pure_v1369:
        setzm vmspace_v1369+020(5)
        aoj 5,
        caige 5,0%o
        jrst wipe_pure_v1369
        movei 1,012345
        movei 2,vmspace_v1369
        movei 3,stable_uarea_v1369
        pushj 17,proc_swap_reload_pure
        jumpn 1,fail13
        pushj 17,verify_image_v1369
        jumpn 1,fail14

        movei 0,2
        movem 0,mode_v1369
        pushj 17,reset_v1369
        pushj 17,load_v1369
        camn 1,[-1]
        jrst check_bad_v1369
        jrst fail9
check_bad_v1369:
        pushj 17,verify_rollback_v1369
        jumpn 1,fail10
        ; A corrupt immutable PURE backing image fails closed too.
        movei 1,012345
        movei 2,vmspace_v1369
        movei 3,stable_uarea_v1369
        pushj 17,proc_swap_reload_pure
        camn 1,[-1]
        jrst check_pure_failed_v1369
        jrst fail15
check_pure_failed_v1369:

        movei 0,3
        movem 0,mode_v1369
        pushj 17,reset_v1369
        pushj 17,load_v1369
        camn 1,[-1]
        jrst check_io_v1369
        jrst fail11
check_io_v1369:
        pushj 17,verify_rollback_v1369
        jumpn 1,fail12
        setz 1,
        popj 17,

load_v1369:
        movei 1,process_v1369
        movei 2,3                    ; test process slot
        movei 3,path_v1369
        pushj 17,exec_load_process
        popj 17,

reset_v1369:
        setzm process_v1369
        setzm process_v1369+1
        setzm process_v1369+2
        setzm attach_count_v1369
        setzm destroy_count_v1369
        setzm attach_pure_v1369
        setzm proc_rt_owner
        setzm unexpected_v1369
        popj 17,

verify_image_v1369:
        movei 5,0
verify_loop_v1369:
        move 6,expected_image_v1369(5)
        came 6,vmspace_v1369+020(5)
        jrst compare_bad_v1369
        aoj 5,
        caige 5,0%o
        jrst verify_loop_v1369
        setz 1,
        popj 17,
compare_bad_v1369:
        seto 1,
        popj 17,

verify_commit_v1369:
        move 0,attach_count_v1369
        caie 0,1
        jrst compare_bad_v1369
        skipn process_v1369+1
        jrst compare_bad_v1369
        move 0,destroy_count_v1369
        jumpn 0,compare_bad_v1369
        move 0,unexpected_v1369
        jumpn 0,compare_bad_v1369
        hlrz 0,process_v1369
        caie 0,020
        jrst compare_bad_v1369
        setz 1,
        popj 17,

verify_rollback_v1369:
        move 0,destroy_count_v1369
        caie 0,1
        jrst compare_bad_v1369
        move 0,attach_count_v1369
        jumpn 0,compare_bad_v1369
        move 0,process_v1369+1
        jumpn 0,compare_bad_v1369
        move 0,process_v1369
        tlne 0,0777777
        jrst compare_bad_v1369
        move 0,unexpected_v1369
        jumpn 0,compare_bad_v1369
        setz 1,
        popj 17,

file_lookup_path:
        movei 0,1
        movem 0,(2)
        setz 1,
        popj 17,
file_check_access:
file_check_root:
        setz 1,
        popj 17,

vfs_stat:
        movei 0,2                    ; VFS_TYPE_REG
        movem 0,(2)
        movei 0,0%o                  ; actual file word count
        movem 0,3(2)                 ; size_words, octal -011 to -006
        setz 1,
        popj 17,

vm_space_create:
        movei 0,vmspace_v1369
        movem 0,1(1)                 ; VM physical base
        setz 1,
        popj 17,

vm_space_load_file:
        aos unexpected_v1369        ; compressed path MUST not use plain VM
        seto 1,
        popj 17,

vm_space_destroy:
        aos destroy_count_v1369
        setzm 1(1)                   ; discard partially filled VM
        setz 1,
        popj 17,

proc_swap_attach:
        aos attach_count_v1369
        movem 4,attach_pure_v1369
        setz 1,
        popj 17,

/* Actual provider layout is a complete *grouped DXR2* file.
 * AC1=vnode, AC2=word offset, AC3=destination, AC4=request words.
 * Return AC1=number read, or -1 for error. Preserve AC10..16.
 * The short-read cap forces multiple grouped input window refills.
 */
vfs_read_words:
        caie 1,1
        jrst provider_fail_v1369
        move 5,mode_v1369
        caie 5,3
        jrst provider_bounds_v1369
        caige 2,0%o
        jrst provider_bounds_v1369
        jrst provider_fail_v1369
provider_bounds_v1369:
        movei 6,0%o
        sub 6,2
        jumple 6,provider_fail_v1369
        camle 4,6
        move 4,6
        caile 4,7
        movei 4,7
        move 1,4
        movei 6,actual_grouped_dxr_v1369
        add 6,2
provider_copy_v1369:
        move 0,0(6)
        ; Mode 1 is PURE and modifies *only* the header BSS/PURE flags.
        move 5,mode_v1369
        caie 5,1
        jrst provider_corrupt_v1369
        caie 2,1
        jrst provider_corrupt_v1369
        iori 0,0200000              ; DXR_F_PURE in RH
provider_corrupt_v1369:
        caie 5,2
        jrst provider_store_v1369
        caie 2,3                    ; first grouped control word
        jrst provider_store_v1369
        setz 0,                      ; noncanonical zero-token group
provider_store_v1369:
        movem 0,(3)
        aoj 2,
        aoj 3,
        aoj 6,
        sojg 4,provider_copy_v1369
        popj 17,
provider_fail_v1369:
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

; Vnode reconstruction is independently tested elsewhere. Supply the
; validated vnode/text count while exercising the actual PURE reload.
proc_swap_unpack_backing:
        movei 1,1
        movei 2,0%o
        popj 17,

.data
path_v1369:
        .word 0
expected_image_v1369:
""" % (image, image, filelen, 3 if compressed_len <= 7 else 0o10,
       filelen, image)
    code += literal(source_words)
    code += file_label + ":\n"
    code += literal(grouped)
    code += """.bss
        .globl proc_rt_owner
proc_rt_owner: .block 1
process_v1369: .block 3
mode_v1369: .block 1
stable_uarea_v1369: .block 0100
attach_count_v1369: .block 1
destroy_count_v1369: .block 1
attach_pure_v1369: .block 1
unexpected_v1369: .block 1
vmspace_v1369: .block 0%o
        .globl __test_exit
__test_exit: .block 1
""" % (image + 0o2020)
    pathlib.Path(destination).write_text(code)
    print("EXEC_NATIVE_FIXTURE_V1369 image=%d encoded=%d actual_loader=yes" %
          (image, compressed_len))


if __name__ == "__main__":
    if len(sys.argv) != 6:
        raise SystemExit("usage: generate_exec_native_v1369.py UNCOMPRESSED.dxr GROUPED.dxr OUT.s PURE_SOURCE PURE_OUT.s")
    generate(sys.argv[1], sys.argv[2], sys.argv[3])
    source = pathlib.Path(sys.argv[4]).read_text()
    start = source.index("proc_swap_reload_pure:\n")
    end = source.index("\n\n/* Provider-independent", start)
    actual = source[start:end]
    if "pushj   17,d6lz36_decode_vfs" not in actual:
        raise ValueError("PURE reload decoder call changed")
    prelude = (".text\n.globl proc_swap_reload_pure\n"
               ".globl proc_swap_unpack_backing\n"
               ".globl vfs_read_words\n.globl d6lz36_decode_vfs\n"
               ".equ EXEC_DXR_F_COMPRESSED,0100000\n"
               ".equ EXEC_USER_ORIGIN,020\n")
    pathlib.Path(sys.argv[5]).write_text(prelude + actual + "\n")
