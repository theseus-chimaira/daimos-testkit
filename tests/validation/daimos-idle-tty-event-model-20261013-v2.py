#!/usr/bin/env python3
"""Executable interleaving model for a future combined PID-1 wait.

This is a design-level regression, NOT a PDP-6 runtime acceptance test.
It makes the atomicity contract explicit before changing the scheduler or
the CTY/DCS/GE interrupt paths. No polling or per-TTY resident process.
"""

import itertools


class Dispatch:
    def __init__(self):
        self.epoch = 0
        self.idle = {0, 1, 17, 20}
        self.ready = {}
        self.finished = set()
        self.sleeping = False
        self.seen = -1

    def input(self, tty, char):
        assert tty in self.idle
        assert tty not in self.ready, "one-byte mailbox overflow"
        self.ready[tty] = char
        self.publish()

    def exited(self, child):
        self.finished.add(child)
        self.publish()

    def publish(self):
        self.epoch += 1
        self.sleeping = False

    def register_wait(self):
        """Snapshot event generation before checking all sources."""
        self.seen = self.epoch

    def arm(self):
        """Atomic with interrupt delivery in the proposed kernel ABI."""
        if self.epoch != self.seen or self.ready or self.finished:
            return False
        self.sleeping = True
        return True

    def consume(self):
        chars = dict(self.ready)
        children = set(self.finished)
        self.ready.clear()
        self.finished.clear()
        return chars, children


def check(order):
    dispatcher = Dispatch()
    for action in order:
        if action == "snapshot":
            dispatcher.register_wait()
        elif action == "arm":
            dispatcher.arm()
        elif action == "tty0":
            dispatcher.input(0, "R")
        elif action == "tty17":
            dispatcher.input(17, "A")
        elif action == "child":
            dispatcher.exited(3)
    chars, children = dispatcher.consume()
    assert chars == {0: "R", 17: "A"}, (order, chars)
    assert children == {3}, (order, children)
    assert not dispatcher.sleeping, (order, "lost wakeup")


def main():
    # Snapshot precedes arm, while inputs and exit can occur anywhere.
    cases = 0
    for order in itertools.permutations(("snapshot", "arm", "tty0", "tty17", "child")):
        if order.index("snapshot") > order.index("arm"):
            continue
        check(order)
        cases += 1
    assert cases == 60
    print("PASS combined idle-TTY/child event interleavings:", cases)


if __name__ == "__main__":
    main()
