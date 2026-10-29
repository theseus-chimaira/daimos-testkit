# MRES packed-vector compact decoder check v684

The current shared decoder uses the operation number's low bit to select
the LH or RH half of each packed vector word. A proposed common-index
rewrite shifts the zero-based operation right before selecting the half,
destroying exactly that parity bit. All eight operation pairs collide:
they share the same vector word, but have different target addresses.

The experiment rejects this invalid transformation and compares an
unchanged-ABI linked baseline against an equivalent safe decoder. Both
occupy 38 isolated linked text words (including identical symbol stubs).
**No memory saving has been demonstrated for second-level dispatch.**

Unlike v681-v682, this is a source-level and link-size rejection test, not
a native execution test of a new candidate. Production DAIMOS was unchanged.
