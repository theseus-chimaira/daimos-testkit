# K03/K01 post-PI6-fix acceptance v1743

Date: 2026-11-21. Exact DAIMOS source:
`03dcb0e9c92a6bea2bb0c4392ef7c638ec681e10`.

After replacing global PI masking with scheduler-PI6-only exclusion
in `mm_alloc_aligned_noreclaim`, the full v1733 K03 matrix was
rerun in three independent disposable 256K PDP-6 KCC guests.
The testkit base recorded by the runner was
`eb1a66f796c0f38b8fdc67ecaeb144bad2578d78`.

| Gate | Result | Guest log SHA256 |
| --- | --- | --- |
| RUN parent / real requester OOM | PASS | `34e438e119c530bd5774ea772480949f2431a476d5621e9c37d48b3ecc21ec75` |
| Held foreign FS lease | PASS | `adca401ae82fe6c8b67d20d896b9c6bcf2b1bbc79ec21bcb071725e60d27d91d` |
| Permanent MM wrong-owner refusal | PASS | `0bd89f4ca8208b87a96d96cf5d4bd561fa3b6eb31bc3ffe19f794627f0a7e9f8` |

Combined runner transcript SHA256:
`fccedf836439118b5304137a5ab8af317101ee7d75fd19b4afcb90f8bb18614f`.

The RUN-parent guest preserved its independent parent and exact WAIT
after real descriptor-saturated RUN cause `-3`. The held-provider
guest observed seven fatal busy retries and successful foreign lease
release with bystander progress and recovered MM accounting. The
permanent-refusal guest observed seven wrong-owner MM failures,
six capped reaper attempts, preserved owner/u-area, unreaped WAIT,
and independent foreign owner/bystander progress. No guaranteed
reclamation under permanent refusal is claimed (K04 remains open).

The updated K01 native suite (`daimos-k01-native-acceptance-v1715.sh`,
selecting PI6-safe v1742 allocator gate) passed all **33** cases.
Native suite transcript SHA256:
`3b90054b496ac1ca78607ad2e277143b0f9a5f40255257acd4cad31366581fca`.

The fresh 256K full-profile D6FS ROOT login/DSH/TRUE/HALT/CLEAN
guest passed separately (v1742 report). These acceptances do not
establish the strict 32K KCORE memory budget or solve K04 policy.
