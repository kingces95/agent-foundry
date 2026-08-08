# Analysis artifact contract

## Chapter map

Every `maps/chapter-NN.json` contains:

- `schema_version` and `kind`
- chapter number and title
- exact input file, hash, and paragraph range
- a bounded prose summary
- ordered major events
- character developments
- themes and motifs
- unresolved or newly resolved narrative threads
- representative source paragraph IDs

Chapter maps summarize only their own input. They may name context from earlier
chapters but must not use later knowledge to rewrite what the chapter reveals.

## Arc reduction

Every `reductions/arc-NN.json` declares a contiguous list of chapter inputs and
their current hashes. It combines the maps into an account of causality,
character movement, thematic development, and threads carried into the next
arc. It is not a concatenation of chapter summaries.

## Document summary

`document-summary.md` is written from the five arc reductions. It includes a
short synopsis, an expanded narrative summary, major character arcs, themes,
and a note on the analysis method. The final prose may reopen cited source
paragraphs to resolve ambiguity, but it may not silently bypass an uncovered
chapter.
