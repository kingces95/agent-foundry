# Jane Eyre analysis build

This directory contains durable, reviewable products of hierarchical
summarization. They are analogous to compiler object files only in that they
have explicit inputs and can be invalidated; unlike ordinary `obj` files, they
are checked in because their editorial judgments are useful work products.

## Layers

- `maps/chapter-NN.json`: one source-grounded map for each of the 38 chapters.
- `reductions/arc-NN.json`: five reductions over contiguous narrative arcs.
- `document-summary.md`: the human-facing whole-book summary.
- `build.json`: generated hashes and coverage evidence for the completed build.

Mechanical scratch data, prompt transcripts, tokenization caches, and rendered
previews do not belong here. Those should be temporary or ignored.

## Build graph

```text
projection/chapters/*.md
        -> maps/chapter-NN.json
        -> reductions/arc-NN.json
        -> document-summary.md
```

The five reductions follow narrative structure rather than equal token sizes:

1. Chapters 1-10: Gateshead and Lowood
2. Chapters 11-20: Thornfield and the growing mystery
3. Chapters 21-27: Return, courtship, and the interrupted wedding
4. Chapters 28-35: Moor House, inheritance, and St. John
5. Chapters 36-38: Return to Rochester and conclusion

## Invalidation

Each chapter map records the exact SHA-256 hash and paragraph range of its
chapter projection. Each arc reduction records the hashes of its map inputs.
`build.json` records the hashes of all five reductions and the final summary.

A changed source chapter invalidates only its map, its containing arc, and the
final summary. This is the key advantage of preserving intermediate artifacts.

## Evidence

Maps and reductions cite stable paragraph IDs such as `p002937`. The validator
checks that every citation exists and belongs to an input chapter. Evidence is
not intended as a quotation database; it is a route back to source context.
