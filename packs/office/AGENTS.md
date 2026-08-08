# Office pack guidance

This pack exposes Microsoft Office capabilities in application-native terms.

- Public commands describe Word, DOCX, OOXML, ranges, paragraphs, styles, and
  formatting—not the vocabulary of a particular manuscript or editing team.
- Live Word mutations use guarded operations and one native undo record.
- Offline DOCX mutations write a separate package and verify its structure.
- Prefer Word's own Find and object model for live work; prefer surgical OOXML
  package edits for closed files.
- Private helpers may change freely. Examples may use only public commands.
- Complex public input must have one authoritative JSON Schema registered in
  the module's schema catalog.
