# v039 — complete DXR native-token-policy model

Research-only Python model of the v036 native encoder's **current token
policy**, run on all 81 DAIMOS-built DXR payloads from the established v006
manifest. Each little-endian 64-bit storage word is checked to fit 36 bits.
The DXR header and relocation directory are omitted, following the v020
comparison loader. Every modeled compressed stream is independently decoded
and checked word-for-word against its DXR payload.

| Result (81 DXR images) | 36-bit words |
|---|---:|
| Raw payload | 159,973 |
| Established v006 paired codec | 131,548 |
| Native encoder policy model | 151,853 |
| Model overhead relative to v006 | 20,305 |

The model saves 8,120 words (5.08%) against raw, compared with v006 savings
of 28,425 words (17.77%). All 81 modeled streams were smaller than raw.
The gap is primarily an algorithm-policy problem: native v036 uses
literal-only groups or singleton word/zero-run groups and cannot emit
aligned-halfword matches, while the host paired codec has flexible token
grouping and even-halfword matches. This attribution is an engineering
hypothesis, not an isolated measured decomposition of the causes.

IMPORTANT: this is NOT a full PDP-6 native encoder run or a measured codec
size. The Python model reproduces the visible v036 token-search and packing
policy; it has not been cross-checked stream-for-stream against full native
DXR execution. Native v038 parity was verified separately on three 128-word
real DXR excerpts. The comparison is useful to prioritize the next
implementation work but is not a formal native equivalence result.

Next steps: isolate the loss due to singleton match token groups and the
loss due to absent halfword matching on identical corpus inputs. Preserve
minimal resident memory, keep the 128-word search, and test assembler
changes in new isolated versioned directories. Do not modify production
DAIMOS or KCORE until concurrent work finishes and full ABI validation.
