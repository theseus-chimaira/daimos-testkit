# Trusted-memory-only bitmap codec v1446

The bitmap stream belongs exclusively to DAIMOS MM. Both encoder input
and the decoder's packed image are kernel-owned. The caller reserves the
output extent, computes and records the exact packed word count, and
guarantees non-overlapping and valid memory ranges. There is no VFS
provider and no independently supplied compressed stream.

This version removes byte-stream bounds tests and capacity checks
inside the codec. It is **not** suitable for arbitrary user-supplied
compressed data or persistent files. The host-side trusted-memory
ownership and exact allocation contract must be satisfied before
calling it.

ABI (test-only): encode AC1=source, AC2=original word count,
AC3=reserved destination, AC4 ignored; returns packed word count
in AC1. Decode AC1=packed source, AC2 ignored, AC3=destination,
AC4=original word count; returns original word count in AC1.

No kernel integration is claimed. Reg save/restore, MM preflight,
relocation, atomic process ownership and rollback are separate.
