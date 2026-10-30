#!/usr/bin/env python3
"""Model volatile variable-size swap exchange with one sector of scratch.

No kernel code is exercised: validate transfer ordering and capacity cases.
Units here are complete 0200-word sectors, not executable words.
"""

def exchange(ra, rb, aoff, boff, sa, sb, extension):
    assert ra >= aoff + sa and rb >= boff + sb
    if rb > ra or sa > sb + extension:
        return None
    ram = [('A', i) for i in range(ra)]
    disk = [('B', boff + i) for i in range(sb)] + [None] * extension
    original_a = list(ram)
    original_b = list(disk[:sb])
    # Sectors beyond B's existing extent are not overwritten by exchange.
    # Preserve A's extra suffix before any B restoration can overwrite it.
    for i in range(sb, sa):
        disk[i] = ram[aoff + i]
    # Overlap is a shifted interval. Memmove-style ordering ensures that
    # B's destination cannot overwrite an as-yet-unread A source sector.
    pairs = range(min(sa, sb))
    if boff > aoff:
        pairs = reversed(pairs)
    for i in pairs:
        saved_b = disk[i]
        disk[i] = ram[aoff + i]
        ram[boff + i] = saved_b
    # B-only tail has no A disk write, but might clobber A yet to be read;
    # all required A sectors have been saved by this point.
    for i in range(sa, sb):
        ram[boff + i] = disk[i]
    assert disk[:sa] == original_a[aoff:aoff + sa]
    assert ram[boff:boff + sb] == original_b
    return True


def main():
    passed = 0
    for ra in range(1, 15):
        for rb in range(1, ra + 1):
            for aoff in range(ra + 1):
                for boff in range(rb + 1):
                    for sa in range(ra - aoff + 1):
                        for sb in range(rb - boff + 1):
                            if exchange(ra, rb, aoff, boff, sa, sb,
                                        max(0, sa - sb)) is not None:
                                passed += 1
    print('v764: %d synthetic layout cases PASS (model only)' % passed)


if __name__ == '__main__':
    main()
