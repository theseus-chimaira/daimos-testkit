#!/usr/bin/env python3
"""Pure preflight model for contiguous variable-sized BACKSTORE exchange.

The already allocated incoming span remains reserved until exchange commits.
An outgoing span requiring additional blocks must extend it contiguously.
"""

def feasible(ram_words, incoming_words, outgoing_blocks, incoming_blocks,
             first, bitmap):
    if incoming_words > ram_words:
        return False
    if first < 0 or incoming_blocks <= 0 or outgoing_blocks <= 0:
        return False
    if first + incoming_blocks > len(bitmap):
        return False
    if any(not bitmap[i] for i in range(first, first + incoming_blocks)):
        return False
    extension = max(0, outgoing_blocks - incoming_blocks)
    if first + incoming_blocks + extension > len(bitmap):
        return False
    return not any(bitmap[i] for i in range(
        first + incoming_blocks, first + incoming_blocks + extension))


def check():
    cases = 0
    for length in range(1, 9):
        for mask in range(1 << length):
            bitmap = [(mask >> i) & 1 for i in range(length)]
            for first in range(length):
                for incoming in range(1, length - first + 1):
                    for outgoing in range(1, length + 1):
                        got = feasible(16, 8, outgoing, incoming, first, bitmap)
                        occupied = all(bitmap[first:first + incoming])
                        extra = max(0, outgoing - incoming)
                        expected = bool(occupied and first + incoming + extra <= length
                                        and not any(bitmap[first + incoming:
                                                           first + incoming + extra]))
                        assert got == expected
                        cases += 1
    # Full pool, equal spans: exchange requires no additional disk blocks.
    assert feasible(26624, 26624, 208, 208, 0, [1] * 208)
    # A larger outgoing image cannot steal blocks owned by another client.
    assert not feasible(26624, 26624, 209, 208, 0, [1] * 209)
    # The incoming image must fit resident RAM, irrespective of backing room.
    assert not feasible(26624, 26625, 208, 208, 0, [1] * 208)
    print('v765: %d contiguous exchange bitmap preflights PASS' % cases)


if __name__ == '__main__':
    check()
