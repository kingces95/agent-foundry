# DOCX corpus

This directory treats large Word documents like source trees. Each fixture keeps
the original `.docx` for provenance and derives text-first projections that can
be searched, diffed, summarized, and patched with ordinary repository tools.

Regenerate the Jane Eyre projection from the repository root with:

```powershell
$python = 'C:\Users\chris\.cache\codex-runtimes\codex-primary-runtime\dependencies\python\python.exe'
& $python .\examples\office\jane-eyre\tools\project_docx.py `
    --input "$env:TEMP\agent-foundry-jane-eyre.docx" `
    --output .\examples\office\jane-eyre `
    --slug jane-eyre `
    --source-url 'https://www.bookrags.com/ebooks/1260/?mode=doc'
```

The projection deliberately has several layers:

1. `source/` is the immutable input and its provenance.
2. `projection/paragraphs.jsonl` is the loss-aware paragraph ledger.
3. `projection/chapters/*.md` is the model- and search-friendly semantic view.
4. `analysis/` is reserved for derived maps and reduce passes. Analysis should
   cite paragraph IDs rather than relying on unstable page layout.

The source hash in `projection/manifest.json` is the concurrency precondition.
If the DOCX changes, regenerate before applying or trusting derived work.

Measured Word COM versus direct OOXML results, failed approaches, and decision
rules for future agents are recorded in
[`lessons.md`](lessons.md).

Validate hashes and full paragraph coverage with:

```powershell
& $python .\examples\office\jane-eyre\tools\validate_projection.py `
    .\examples\office\jane-eyre
```
