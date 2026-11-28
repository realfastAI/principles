Recover the outlines a survey left out without scanning the project again. Give one or more literal file paths:

%{executable} show-candidate-outlines guides/names.md guides/checks.md

The command reads only those files, without glob expansion or recorded guidance search paths. Leading `./` is
removed; repeated paths are listed once, in path order. Paths must resolve to regular UTF-8 text files inside
the selected project, through any symbolic links too. Each failed path appears under `inventory.unreadable`
with its `code`, `message`, `repair` and `path`; other requested files still succeed, with exit 0 and `wrote: []`.
No paths is a usage refusal, exit 2. In git, `ignored` names unread requests, including aliases whose text depends
on ignored links or targets. Their contents are not read. No success is inferred for a refused or ignored file.

`inventory.files` uses the survey's entries: `path`, `characters`, and `symlink_to` when linked. Markdown gives
`outline`, with its headings and top-level list items, and any `description` and `opening_line` as in
list-candidate-files. Explicitly requested test-data files and skill references receive outlines too: you chose them,
and you judge relevance. A CI workflow in `.github/workflows/` gives each job, `job ID: NAME`, followed by its steps,
each by its name or else what it runs or uses; one whose YAML does not parse gives path and size alone. Other text, such
as a script or a hook, gives its whole-line `#` comments as its `outline`, where such a file states the rule it
enforces, its shebang and Ruby magic comments (`frozen_string_literal`, `typed`, `encoding`, `coding`, `warn_indent`,
`shareable_constant_value`) left out; text with none gives path and size alone. Past 20 items under one heading, or 20
comments, `(N more, lines A-B)` gives the lines from the first left out to the section's end. Open a file only if
needed.

The full rendered result uses the survey's byte budget. `outlines_cut` names shortened outlines, whose line-range
markers show where to read needed items. `outlines_left_out` names files whose outlines were omitted: request
fewer paths to recover them. Root entry files retain their outlines and can exceed the budget on their own;
if one file is still too large, read only its needed headings or line ranges. A result with cuts or omissions
is incomplete; never treat it as a complete reading of the requested files.
