# Native PURE DROP backing availability, v1926

Run using the installed PDP-6 toolchain:

    DAIMOS_REPO=$HOME/git/DAIMOS make test-pure-drop-availability-v1926

The guest links actual RAW DROP and MM rebase instructions with the
established controlled MM, mount, PI and provider-publication fixtures.
108 cases exercise public mount IDs 1 and 18, all four filesystem
providers, unavailable or malformed JRST bindings, the resident refusal
fallback, DTFS READ_SUSPECT/WRITE_UNCERTAIN/QUIESCING, absent or incomplete
mounted identity, inconsistent V2 armed/read-only policy, absent D6FS
reader and absent TSFS locator/member metadata. Valid legacy, stamped
and armed writable DTFS are still admissible. The controlled PI boundary
can retire the root, substitute a provider or remove the root slab
between early admission and final PI-excluded proof.

Refusal must preserve the complete resident image (text and suffix),
original extent and pin state, backing, RESIDENT mode and TRANSITION.
No allocation or free occurs; PI disable/restore remains balanced.
Five independently executed unsafe candidates fail native assertions:
missing service fallback check (04022), DTFS poison (05052), final root
identity (04302), missing D6FS reader (06152) and missing TSFS extent
metadata (07212), all octal. Native test-only provider publication and
read-only policy are explicit; they are not actual provider I/O.

Historical v1382 high-mount fixture now initializes the v1924 saved
provider. The v1924 admission mutant removes both early and final
provider comparisons to test actual unsafe substitution; v1926 tests
the final comparison independently. The v1608 admission, v1612 service,
v1918/v1919 recovery, v1923/v1924 identity and v1925 bridge gates pass.
The terminal path is unchanged and does not depend on backing presence.
This is a non-sleeping admission proof of known availability, not a
physical identity proof for D6FS/TSFS or a full-guest PI6 race test.
