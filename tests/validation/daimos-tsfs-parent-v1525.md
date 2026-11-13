# Native PDP-6 TSFS parent/name helper polarity, v1525

Date: 2026-11-13. Source-linked actual TSFS
`tsfs_parent_common`, `tsfs_parent`,
`tsfs_parent_name` and VFS SIXBIT name parsing.
Only the physical TSFS file-record acquisition
boundary is controlled by the test fixture.

The helper returns a **parent vnode** on success,
not a zero success status. The old wrappers used
`JUMPN` for an error branch and consequently
rejected all valid nonzero parent vnodes,
breaking TSFS mount-boundary GETCWD and FSINFO.

The corrected `JUMPL` wrappers passed on the
real PDP-6 native instruction runner for both
root and intermediate-node parents, and decoded
the actual `DT0` SIXBIT name with length 3.
The missing-file-record negative path retains
both output buffers untouched. Two executable
mutants each restore one of the old `JUMPN`
branches and are independently rejected.

This regression does not substitute for
the subsequently completed full physical v1525
mounted-DTFS/FSINFO/GETCWD/FILE lifetime guest.
