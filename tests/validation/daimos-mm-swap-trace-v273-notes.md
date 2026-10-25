# 256K pressure admission traces — v273/v274

The 256K pressure workload from v272 creates seven sleeping children,
then fails to create the eighth (`<wp7!W`). The following tests trace
production native PDP-6 routines using SIMH execution breakpoints; they
make no changes to KCORE or the test guest image.

* v273 breakpoints: `exec_load_process`, `proc_swap_reclaim`, `proc_swap_out`.
  Guest fails as before; reclaim and swap-out are reached once.
* v274 breakpoints: `proc_swap_reclaim`, `proc_swap_victim`,
  `proc_swap_out`, `proc_storage_expect_v30`, `backstore_alloc`,
  `backstore_write`, `mm_free`. During the run, observed entry counts:
  reclaim 1, victim selection 1, swap-out 1, backstore allocation 1,
  backing-store write 1, storage-state check 11 and MM free 21.
  Guest still fails with `p7`.

Breakpoint entry counts are **not** success status. In particular, entering
`backstore_write` does not establish that its return value is zero.
Continue tracing `backstore_write` return/rollback and MM reclamation
before altering memory capacity or swapping policy. No swap acceptance
has been established.
