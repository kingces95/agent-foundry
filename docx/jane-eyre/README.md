# Jane Eyre large-document experiment

This fixture asks a concrete question: how should Codex work with a Word
document that is too large to treat as one prompt?

The answer being tested is to use Git as external memory. The DOCX is projected
into stable, addressable files, and later analysis is built as explicit map and
reduce artifacts rather than hidden conversational state.

## Layout

- `source/jane-eyre.docx`: downloaded input, retained byte-for-byte.
- `source/source.json`: provenance and source hash.
- `projection/manifest.json`: counts, hashes, coverage, and part boundaries.
- `projection/paragraphs.jsonl`: every Word paragraph, including page-marker
  paragraphs and run-level formatting.
- `projection/tables.jsonl`: every table, row, cell, and cell paragraph.
- `projection/chapters/*.md`: readable semantic shards with paragraph IDs.
- `analysis/`: checked-in summaries and indexes derived from the projection.

The Markdown projection omits empty paragraphs and generated `Page N` marker
paragraphs. Nothing silently disappears: those records remain in the JSONL
ledger and every omission is counted in the manifest.

## Search examples

```powershell
rg -n -i "red-room" .\docx\jane-eyre\projection\chapters
rg -l -i "St\. John" .\docx\jane-eyre\projection\chapters
rg -n '"kind":"chapter-heading"' .\docx\jane-eyre\projection\paragraphs.jsonl
```

## Implemented analysis pipeline

1. **Map:** summarize each chapter into a small structured JSON artifact with
   characters, events, themes, settings, and cited paragraph IDs.
2. **Validate:** ensure every chapter in the manifest has exactly one map and
   every cited paragraph belongs to that chapter's source range.
3. **Reduce:** combine chapter maps into section summaries, then reduce those
   into a document synopsis, character arcs, chronology, and thematic index.
4. **Invalidate:** if the source or chapter hash changes, mark dependent maps
   and reductions stale and regenerate only the affected branch.

This makes “ingesting the whole document” a coverage property we can verify,
not a claim that every source token was simultaneously present in one prompt.

The completed book-level result is in
[`analysis/document-summary.md`](analysis/document-summary.md). Its durable
intermediates and validation record are described in
[`analysis/README.md`](analysis/README.md); rerun validation with:

```powershell
python .\docx\tools\validate_analysis.py --write-build
```
