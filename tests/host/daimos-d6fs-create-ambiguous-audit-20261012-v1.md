# D6FS create-path ambiguous FCB result audit (2026-10-12)

PDP-6 assembly `system/kernel/fs/d6fs_provider_namespace_pdp6.s` publishes
an allocated FCB using `d6fs_reader_put_fcb` and immediately uses
`jumpn 1,d6fs_create_fail`. The directory entry is written *later* in
`d6fs_create_dirent`. A synthetic backing callback that successfully
writes the FCB but returns an error will leave a durable FCB that has no
published parent directory entry. Unlike the `d6fs_create_dirent_fail`
path, this early branch makes no attempt to resolve the uncertain FCB.

This is a concrete mechanism consistent with FCB 0451 and 0452 being
unreachable in the injected run. Both are in physical FCB block 479, the
injection target. The clean, non-fault control had no orphaned FCBs.
**Causation is supported by the source branch and shared block, but has not
been confirmed with a per-write hit trace.**

Do not simply clear the FCB: it may already be durable. Correct resolution
requires a proven recovery decision for ambiguous FCB writes and for the
related directory-entry publication ordering. This audit reports the
known branch without pretending it fixes transactional recovery.
