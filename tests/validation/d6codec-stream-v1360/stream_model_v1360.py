"""Bounded grouped-D6CODEC refill decoder specification (test-only)."""


class InvalidStream(ValueError):
    pass


class Reader:
    """Simulate a bounded source refill callback without rewinding input."""

    def __init__(self, words, window):
        if window < 1:
            raise ValueError("window must be positive")
        self.words = words
        self.window = window
        self.position = 0
        self.end = 0
        self.refills = 0
        self.consumed = 0

    def take(self):
        if self.position == self.end:
            self.position = self.end
            self.end = min(self.end + self.window, len(self.words))
            self.refills += 1
        if self.position == self.end:
            raise InvalidStream("truncated compressed input")
        word = self.words[self.position]
        self.position += 1
        self.consumed += 1
        if not 0 <= word < (1 << 36):
            raise InvalidStream("invalid physical word")
        return word


def decode(words, expected_count, window):
    """Decode by control/descriptor/literal phases with <=15-word scratch.

    Return (output, maximum_descriptor_words, refills) on exact success.
    No complete stream or group is copied into the scratch region.
    The input is an immutable external source; output is the LZ history.
    """
    if not 0 <= expected_count <= 0o777777:
        raise InvalidStream("invalid output length")
    if len(words) > 0o777777:
        raise InvalidStream("invalid source length")
    reader = Reader(words, window)
    output = []
    peak = 0
    while len(output) < expected_count:
        control = reader.take()
        count = control >> 30
        if count < 1 or count > 30:
            raise InvalidStream("invalid token count")
        flags = control & ((1 << 30) - 1)
        if flags & ((1 << (30 - count)) - 1):
            raise InvalidStream("noncanonical control padding")
        matches = sum((flags >> (29 - i)) & 1 for i in range(count))
        descriptors = [reader.take() for _ in range((matches + 1) // 2)]
        peak = max(peak, len(descriptors))
        if matches & 1 and (descriptors[-1] & 0o777777):
            raise InvalidStream("noncanonical descriptor padding")
        index = 0
        for i in range(count):
            if not (flags & (1 << (29 - i))):
                if len(output) == expected_count:
                    raise InvalidStream("literal beyond output limit")
                output.append(reader.take())
                continue
            word = descriptors[index // 2]
            descriptor = ((word >> 18) if index % 2 == 0 else word) & 0o777777
            index += 1
            kind = descriptor >> 16
            length = (descriptor >> 9) & 127
            distance = descriptor & 511
            if not length or len(output) + length > expected_count:
                raise InvalidStream("invalid match length")
            if kind == 1 and distance == 0:
                output.extend([0] * length)
            elif kind in (0, 2):
                if kind == 2:
                    if distance & 1:
                        raise InvalidStream("unsupported odd-half distance")
                    distance //= 2
                if not 1 <= distance <= len(output):
                    raise InvalidStream("invalid copy distance")
                for _ in range(length):
                    output.append(output[-distance])
            else:
                raise InvalidStream("invalid token kind or zero distance")
        if len(output) == expected_count:
            break
    if reader.consumed != len(words):
        raise InvalidStream("trailing compressed input")
    return output, peak, reader.refills


class Resumable:
    """One-way word-window decoder: 1 NEED_INPUT, 0 exact completion.

    Each feed consumes the supplied window without retaining input words.
    Only <=15 descriptor words and scalar group state survive NEED_INPUT.
    """

    def __init__(self, expected_words, compressed_words):
        if not (0 <= expected_words <= 0o777777 and
                0 <= compressed_words <= 0o777777):
            raise InvalidStream("invalid stream extent")
        self.expected = expected_words
        self.compressed = compressed_words
        self.consumed = 0
        self.output = []
        self.phase = "control"
        self.flags = 0
        self.count = 0
        self.index = 0
        self.matches = 0
        self.descriptors = []
        self.match_index = 0
        self.peak = 0
        self.done = False

    def _next_token(self):
        self.index += 1
        if self.index == self.count:
            self.phase = "control"
            if len(self.output) == self.expected:
                self.done = True
        else:
            self.phase = "token"

    def feed(self, words):
        """Consume one entire caller-owned window; return +1 or zero.

        The caller retains ownership of the window and replaces it only
        after NEED_INPUT. Premature complete output is held until the
        declared compressed input has been consumed exactly.
        """
        if self.done and words:
            raise InvalidStream("trailing input after completion")
        for word in words:
            if self.done or self.consumed >= self.compressed:
                raise InvalidStream("unframed trailing input")
            self.consumed += 1
            if not 0 <= word < (1 << 36):
                raise InvalidStream("invalid source word")
            if self.phase == "control":
                if len(self.output) == self.expected:
                    raise InvalidStream("extra group")
                self.count = word >> 30
                self.flags = word & ((1 << 30) - 1)
                if not 1 <= self.count <= 30:
                    raise InvalidStream("bad group count")
                if self.flags & ((1 << (30 - self.count)) - 1):
                    raise InvalidStream("noncanonical flags")
                self.matches = sum((self.flags >> (29 - i)) & 1
                                   for i in range(self.count))
                self.descriptors = []
                self.match_index = 0
                self.index = 0
                self.phase = "descriptors" if self.matches else "token"
            elif self.phase == "descriptors":
                self.descriptors.append(word)
                self.peak = max(self.peak, len(self.descriptors))
                if len(self.descriptors) == (self.matches + 1) // 2:
                    if self.matches & 1 and word & 0o777777:
                        raise InvalidStream("noncanonical descriptor half")
                    self.phase = "token"
            elif self.phase == "literal":
                if len(self.output) == self.expected:
                    raise InvalidStream("literal overrun")
                self.output.append(word)
                self._next_token()
            else:
                raise InvalidStream("unexpected input state")
            # Zero-input tokens can be decoded without consuming input.
            while self.phase == "token":
                if not self.flags & (1 << (29 - self.index)):
                    self.phase = "literal"
                    break
                descriptor_word = self.descriptors[self.match_index // 2]
                descriptor = ((descriptor_word >> 18)
                              if self.match_index % 2 == 0
                              else descriptor_word) & 0o777777
                self.match_index += 1
                kind = descriptor >> 16
                length = (descriptor >> 9) & 127
                distance = descriptor & 511
                if not length or len(self.output) + length > self.expected:
                    raise InvalidStream("invalid output length")
                if kind == 1 and distance == 0:
                    self.output.extend([0] * length)
                elif kind in (0, 2):
                    if kind == 2:
                        if distance & 1:
                            raise InvalidStream("odd halfword distance")
                        distance //= 2
                    if not 1 <= distance <= len(self.output):
                        raise InvalidStream("invalid copy source")
                    for _ in range(length):
                        self.output.append(self.output[-distance])
                else:
                    raise InvalidStream("invalid descriptor kind")
                self._next_token()
        if self.consumed == self.compressed:
            if self.done or (not self.expected and not self.compressed):
                return 0
            raise InvalidStream("truncated final group/output")
        return 1
