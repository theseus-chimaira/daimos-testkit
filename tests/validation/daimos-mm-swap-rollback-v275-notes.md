# v275 256K swap-out rollback trace

The v272 diagnostic guest still emits `<wp7!W`.
Native SIMH execution breakpoints observed one `backstore_write`,
one `mm_unpin`, one `backstore_free`, and **no**
`proc_storage_publish_v30` entry. This is the characteristic
swap-out rollback sequence after the backing-store write.
The return value of `backstore_write` was not directly sampled,
so the precise cause of its failure is not yet established.
No change to production code or successful swap test is claimed.
