# D6FS ambiguous FCB failure: read-only on-disk forensics (2026-10-12)

The test-only C99 utility compiles an instrumented *copy* of current
DAIMOS `tools/host/d6fsck.c` and prints both raw 16-word FCBs and decoded
metadata for octal indices 0451 and 0452. It uses d6fsck's actual logical
block mapping and performs a complete read-only consistency check.

## Observed state on preserved SIMH images

| FCB (octal) | Injected ambiguous FCB error | Clean control |
| --- | --- | --- |
| 0451 | regular type 1; size 0; zero extents; parent 0; unreachable | regular type 1; size 6; one extent; parent 0; no fsck errors |
| 0452 | regular type 1; size 0; zero extents; parent 0; unreachable | type 0 (free), all 16 words zero |

Fault image: superblock 0670, seq 3, CLEAN-marked but d6fsck reports
FCB 0451/0452 reference count 0 and unreachable. Control image:
`d6fsck` CLEAN with no errors. FCB 0451 in the control has an allocated
extent and six words of data; it appears to be a runtime-created file.

This is strong evidence that synthetic post-write errors during *FCB
creation* leave persistently published empty FCBs before a directory entry
can be committed. It is not proof that the HISTFILE path in particular
created those FCBs, nor that a different test boot would use the same
indices. Also note that `parent=0` alone is not sufficient to identify the
owning directory because root may have index zero.

The kernel source's create-object path first writes an FCB, branches to
`d6fs_create_fail` on any return error, and only afterwards writes the
dirent. The observed FCBs are consistent with a successful physical FCB
write followed by the synthetic negative return. Do not fix this by
blindly zeroing potentially durable metadata: a recoverable publication
protocol must handle uncertain FCB and dirent commits, including crashes.
