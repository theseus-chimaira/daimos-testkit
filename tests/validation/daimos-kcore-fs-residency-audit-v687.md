# v687: KCORE filesystem residency audit

The full v686 KCORE map and current `fs_mres.s` / `vfs.s` show exactly one
128-word fixed filesystem transfer workspace, `fs_block_workspace`.
Physical-provider requests are serialized across sleeping I/O, allowing the
workspace to be shared by DTFS, TSFS and D6FS.

The four mount/reader table bases (`d6fs_reader_slots_base`,
`dtfs_media_base`, `tsfs_file_shape_base`, `tsfs_extent_media_base`) each
occupy one permanent pointer word, referring to MM-managed storage. There
is additionally one active D6FS reader pointer and a shared provider lock
word. Deleting these words is not safe without changing their consumers.

The existing blockset mapping state also exposes aliases of the same words
rather than allocating a second copy. No duplicate 128-word buffer was found
in the inspected permanent filesystem sources.

Conclusion: the obvious large-buffer consolidation was already performed.
The audit found **no safe additional RAM saving**, so it makes no production
change. This regression guards the important workspace-sharing invariant and
uses the linked map rather than treating source declarations as proof of
resident code size. It does not claim to cover unrelated kernel subsystems.
