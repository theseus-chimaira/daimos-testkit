# v690 — MRES gateways: per-site classification

Analysis limited to MRES dispatch, installed bindings and runtime lifecycle.
This is a representative, verified gateway classification, **not** a claim
that every indirect call in DAIMOS has been inventoried.

| Gateway | Classification | Correct next action |
| --- | --- | --- |
| `fs_provider_reg_call` | VFS provider choice + shared sleeping-I/O lock | Retain without a proven equivalent lock |
| `fs_mres_vector_dispatch` | 18-bit-packed operation selection + C ABI | Compare full implementations including vectors |
| `fs_mres_context_vector_dispatch` | Context-aware MEMFS operation selection | Preserve context and stack ABI |
| `storage_pi_handler`, `storage_dct_handler` | Runtime Type-136 hardware ownership | Retain interrupt routing |
| `mfsdev_lookup_entry_v16` and peers | KINIT-patched fixed entry | Already direct binding; no extra lookup to remove |
| `sys_logstore_service_jump`, `sys_mtc_service_jump` | Optional syscall service entries | Already one patched jump; not a generic dispatcher |
| `blockset_runtime_service_jump` | Optional VOLUME mapper | Must fail closed when mapper absent |
| `memfs_reclaim_jump`, `memfs_shutdown_jump` | Optional service with distinct absent behavior | Preserve `0`/success behavior when absent |

The existing `module_runtime_pdp6.s` relocator is deferred and not in the
boot link. Removing direct-entry slots without a replacement relocation
scheme would conflict with future moving/removable modules. MRES-absence
semantics also vary: blockset mapper absence must produce an error rather
than silently access the wrong volume member; reclaim/shutdown absence
returns success/zero. Those behaviors prohibit uniform blind replacement.

Conclusion: KINIT has already removed generic dynamic symbol resolution
from fixed service calls. The remaining control flow is primarily actual
runtime selection, synchronization, or optional-service lifecycle handling.
No production patch is justified solely by this classification.
