# Office Cursor: Make Word Documents Look Like Code

Microsoft Copilot's current Word automation is too slow and unreliable for serious document work. A better solution is to let Codex, ChatGPT, or another capable coding agent automate Word through a representation designed for agents.

The core hypothesis is that a Word document can be projected into a canonical, logical tree that looks like a source-code repository. The agent works against a clone of that representation using familiar filesystem operations: search, inspect, patch, diff, validate, and commit. A deterministic transformation engine then applies the resulting changes back to Word.

```text
Word document
    ↓ capture
Canonical document tree
    ↓ clone
Agent working tree
    ↓ Codex edits
Tree diff
    ↓ compile
Validated Word transforms
    ↓ preview / commit
Live Word document
```

## Why This Should Be Faster

An agent should not repeatedly query Word through small COM calls. Crossing the COM boundary hundreds or thousands of times would make interactive use intolerably slow.

Instead:

1. Capture the document in one relatively expensive operation.
2. Materialize it as local files.
3. Let Codex search and edit those files at filesystem speed.
4. Calculate a structural diff.
5. Apply only the changed operations back to Word.
6. Refresh only affected parts of the logical tree.

The important performance measurements will be:

```text
initial document capture
incremental refresh
agent search and inspection
diff calculation
preview generation
transform application
post-application verification
```

## The Document Worktree

The agent-facing clone could look like:

```text
.document/
├── manifest.yaml
├── document.yaml
├── styles.yaml
├── numbering.yaml
├── body/
│   ├── 0001-introduction.wdoc
│   ├── 0002-background.wdoc
│   └── 0003-proposal.wdoc
├── headers/
│   ├── section-001-primary.wdoc
│   └── section-001-first-page.wdoc
├── footers/
├── footnotes/
├── endnotes/
├── comments/
├── relationships/
├── assets/
└── anchors.jsonl
```

Codex can then use ordinary repository operations:

```text
rg "contractor" body/
inspect styles.yaml
edit body/0003-proposal.wdoc
diff the working tree
run document validation
```

Large documents naturally become multiple files. Codex can search the whole tree while loading only relevant sections into model context.

## Two Representations Are Necessary

A Markdown conversion alone cannot preserve enough Word information. Word documents contain:

- styles and direct formatting;
- sections and stories;
- headers and footers;
- numbered lists;
- fields;
- hyperlinks;
- bookmarks;
- content controls;
- comments;
- tracked changes;
- footnotes and endnotes;
- tables, shapes, and embedded objects.

The system therefore needs two related representations:

1. **Semantic projection:** concise, readable files optimized for agent reasoning.
2. **Lossless anchor map:** structural metadata required to locate and update the original Word objects.

For example:

```text
@paragraph id=p-01842 style="Body Text"
The agreement begins on {{field:id=f-0031}} and remains effective...

@quote id=p-01843 style="Quote"
Either party may terminate this agreement...
```

The visible syntax should be pleasant enough for an agent to generate correctly, while IDs and metadata preserve the connection to Word.

## Stable Identity

Every significant node needs a stable logical identity:

```text
document
section
story
paragraph
table
row
cell
run
field
bookmark
content control
comment
image
```

An identity cannot depend exclusively on character offsets because offsets change after every insertion. It may combine:

- persistent Word identifiers where available;
- structural paths;
- neighboring-node identities;
- content fingerprints;
- original character ranges;
- style and story information.

When an edit is applied, the engine resolves the node again and detects ambiguity instead of modifying the wrong content.

## Editing Model

Codex edits a clone, never the authoritative snapshot:

```text
authoritative snapshot
        ↓ clone
agent working tree
        ↓ edits
structural diff
```

A diff might compile into:

```json
[
  {
    "operation": "set_font",
    "targets": {
      "story": "main",
      "styles": ["Normal", "Body Text"]
    },
    "exclude_styles": ["Heading 1", "Heading 2", "Quote"],
    "font": "Aptos"
  },
  {
    "operation": "replace_text",
    "node_id": "p-01842",
    "start": 14,
    "length": 8,
    "text": "commences"
  }
]
```

Those operations can be validated before Word sees them.

## Clone-First Verification

For risky operations:

1. Make a catastrophic backup.
2. Use Word's `SaveCopyAs` to create a temporary document clone.
3. Apply compiled transforms to the clone.
4. Reopen or reparse it.
5. Regenerate its logical tree.
6. Verify that the intended diff occurred.
7. Render or compare the document when layout matters.
8. Present the preview.
9. Apply the same validated transform set to the live document.

This separates agent creativity from document integrity.

## Applying Changes Efficiently

The apply engine should minimize COM traffic:

- batch related updates;
- operate on whole ranges where possible;
- avoid per-character and unnecessary per-run calls;
- apply textual edits from the end of a story toward its beginning;
- use a single custom Word undo record;
- suspend screen updating when appropriate;
- retain a document revision and reject stale changes;
- recapture only affected stories after completion.

The performance target is not merely "faster than Copilot." It should feel interactive:

```text
small inspection:         effectively immediate
document snapshot:        a few seconds at most
preview calculation:      subsecond after agent completion
ordinary commit:          approximately one second
large batch operation:    visibly progressive and cancellable
```

## REPL as an Escape Hatch

The tree-and-transform workflow should be the normal path because it supports preview, validation, and rollback.

The persistent PowerShell REPL remains available when Codex needs access to an obscure part of Word's object model:

```text
Normal path:
document tree → patch → validated transforms

Escape hatch:
persistent REPL → direct Word COM
```

Direct REPL operations receive stronger warnings and backups because arbitrary code cannot promise transactional behavior.

## Initial MVP

The first version does not need lossless support for every Word feature.

It could support:

- open-document discovery;
- main body, headers, and footers;
- paragraphs and tables;
- paragraph styles;
- character formatting;
- text search and replacement;
- stable paragraph identities;
- canonical worktree export;
- agent-edited clones;
- structural diff;
- preview;
- custom undo record;
- automatic backup;
- commit and rollback;
- persistent PowerShell escape hatch.

The first compelling demonstration is:

> Clone a 200-page Word document into an agent worktree. Ask Codex to change body text to Aptos while preserving headings, quotations, headers, footers, tables, and directly formatted exceptions. Produce an exact preview, apply the change in one undoable operation, and verify the result.

That would demonstrate the essential advantage over Copilot: speed, correctness, inspectability, and control.
