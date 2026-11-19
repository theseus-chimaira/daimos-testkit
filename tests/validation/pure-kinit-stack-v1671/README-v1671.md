# v1671: physical KINIT pushdown-list high-water on TSFS/PURE PDP-6

Exact accepted DAIMOS parent v1670:
`c3867558cd05d0d8be6a179529342cfcda1075f6`.

## Scope

The KINIT native assembler has supported the opt-in
`KINIT_STACK_WATERMARK=1` sentinel fill/scan since v639/v655.
v1671 uses that existing feature for a source-matched comparison
of general and strict swapless TSFS/PURE GCC lowmem boot images,
each on physical 48K and 64K SIMH PDP-6. The images use the
same `KINIT_STACK_RESERVE_WORDS=0400` (256 words), root and
PURE configuration, except the v1668 strict DISK SWAP package
omission. Bitmap mode3 is OFF. Every run has private copies of
all physical DECtape media with DSK/DRM AUXSTORE detached.

The diagnostic flag adds exactly one fixed KCORE word for
`kinit_stack_highwater`, and boot-only sentinel initialization,
measurement and tracking code. With the flag OFF (production),
the original resident and KINIT code/stack geometry is unchanged;
do not conflate instrumented KCORE sizes with normal v1670.

## Independent physical proof

`run-physical-v1671.sh` builds the two diagnostic images or
accepts already linked source-built images through
`V1671_GENERAL_BUILD` and `V1671_STRICT_BUILD`. Its SIMH
breakpoints are derived from the exact KINIT linker map:

* `kinit_stack_watermark_begin`: confirms the sentinel initializer
  ran once at actual original guest execution;
* `vm_enter_initial_user`: reads the native `kinit_stack_highwater`
  from KCORE, the patched permanent resident word and all 256
  physical words beginning at that guest's `__kinit_image_end`.

The original KINIT watermark fill sets unused upper stack words
to PDP-10 octal `525252525252`; the measured high-water is the
highest index above `__kinit_image_end` where the sentinel was
replaced. `measure-v1671.py` independently verifies every
physical stack word, exactly one initializer/terminal breakpoint,
valid actual core size, positive PURE selection, safe reserve
endpoint, equality of native high-water and physical last-touched
offset, and an untouched upper suffix. Missing/duplicate physical
readings or unexpected failures are rejected, not counted PASS.

## Accepted source-built results

| Physical core | General offset | Strict offset | Untouched upper words |
| --- | ---: | ---: | ---: |
| 48K | 129 | 129 | 126 |
| 64K | 129 | 129 | 126 |

The highest used stack address is offset **129 decimal** from
the first reserved stack word. The measured footprint therefore
extends through **130** words of the 256-word reserve, leaving
126 words of physically untouched upper stack. Both configurations
reproduce this exact reading at both core sizes. The normal
linked KCORE end increases by **one** diagnostic-only word
(octal `024076` -> `024077`), and live low resident increases
accordingly (48K: 17725->17726, 64K: 17741->17742). The
source-matched instrumented strict KINIT image still saves
exactly **1877** transient words versus instrumented general.

This is evidence about the exercised boot path, NOT evidence that
the system can universally reduce the default KINIT stack
reserve. Different device/root error paths, recursion depth and
fault handling may use more stack. No change to the default
`0400` reserve or KCORE production code is made in v1671.

## Unsafe measurement variants

`run-negative-v1671.sh` operates on real retained 48K physical
stack transcript bytes and executes four negative cases:

* increment the stored `kinit_stack_highwater` (physical scan
  disagrees with the reported high-water);
* alter the final high-address stack sentinel (unsafe overrun);
* delete the actual initializer breakpoint marker (no proof
  that the physical upper words were initialized);
* forge the stored JSON high-water offset (the source-matched
  comparison rejects internally contradictory evidence).

All four are rejected by the exact original measurement/comparison
oracles, independently of the simulator runs. The physical
runner invokes the negative suite after all four positive runs.

## Next RAM acceptance

Apply appropriately isolated native process-pressure workloads
after `vm_enter_initial_user`, with per-event MM arena/pin/
process ownership accounting at 48K/64K. KINIT stack fail-stop
paths and deeper root configurations need separate stack bounds
before any `KINIT_STACK_RESERVE_WORDS` reduction. Bitmap-mode3
RUN/EXIT/WAIT/PI6 and strict physical 32K remain open.
