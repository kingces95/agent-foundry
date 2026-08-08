# Bespoke editing workflows

Each child directory describes the vocabulary and repeated practices of one
editing universe. Bespoke scripts may compose public `OfficeCursor.Word` and
`OfficeCursor.Docx` commands and never depend on either module's private code.

Start a new profile by copying `MonasticManuscript`, replacing its style-role
map, and adding commands named for the team's actual editorial work.

Keep a command here while its meaning depends on a particular manuscript or
team. Promote only a reusable Word or DOCX mechanism into a core module. A
general-looking parameter list does not make business logic a public primitive.
