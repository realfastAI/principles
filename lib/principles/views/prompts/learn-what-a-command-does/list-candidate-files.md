Lists the files in this project that look like agent guidance, and asks you to show the user a
table of the principles they reinforce before asking anything, then which one to map.
Run it before mapping, or to survey guidance a change carries in a project already mapped.
With maps present, `mapped_principles` lists their ids and descriptions for you to compare with each surveyed rule;
`existing_maps` keeps the ids alone. Judge whether a rule is a facet of one before creating a distinct principle.
After showing the table, add-member extends an existing map and create-principle starts a distinct one.
A map that cannot be read has a `refusal` row with its path and repair instead of a description;
the survey stays available, but resolve that repair before treating a rule as distinct.
To include other guidance now, repeat `--also GLOB`, quoting each root-relative glob so the shell does not expand it:

%{executable} list-candidate-files --also 'guides/**/*.md' --also 'docs/agents/*.md'

Recorded globs in `.principles/guidance-search-paths.json` are reused automatically; `recorded_guidance_search_paths`
lists them when nonempty. `--also` adds temporary selections; `additional_search_paths` counts each normalized glob once
across both sources. Missing configuration is empty and creates nothing. Unusable configuration is refused rather
than silently omitted; see add-guidance-search-path's repairs. After the table, ask where else guidance lives.
Globs match case-sensitively: `*` stays in one path segment, `**/` includes deeper folders, braces select alternatives,
and dotfiles are included. A leading `./` is normalized. Blank or absolute globs, parent segments and NUL are refused
as `invalid_guidance_search_path`. The inventory still skips internal stores, installed-package folders and nested Git
projects, and does not traverse symlinked folders. `additional_search_paths` gives each normalized `glob` and its
`matched_files` count within those boundaries, before ignore/readability filtering; zero means no eligible match,
not proof that no guidance exists elsewhere. Ignored matches remain unread under ignored facts; other unreadable
matches give per-path refusals. Overlapping globs list a file only once. Explicit selections are named even inside
skills: Markdown receives an outline subject to the budget and test-data exclusions, while other text files give
path and size. They are never executed, and listing does not establish host delivery.
`--commits-after REV` names the commit a change starts after, as a sha, a branch or `HEAD~3`, for a survey of the
principles that change carries. The files the commits after REV changed, up to HEAD, list first, each marked
`changed_in_range`, with any Markdown file they changed outside the places hosts load and any changed file already
named in a readable principle map. Range-selected Markdown references inside skills are outlined too; a mapped
non-Markdown file is named by path and size, never executed. Unmapped application code is not included just because
it changed. Selection compares the map's literal member paths; a change only to a symlink target is not promised
to select every mapped alias. Every other candidate follows,
as without it. Past the budget, every other file's outline is left out before theirs is cut, and theirs is never
left out, as an entry file's is not; when they alone pass the budget, `range_outlines_bytes` gives what they print and
the question asks you to name a later REV or choose which to survey. `uncommitted` names each Markdown file that differs from HEAD or is untracked,
since no commit in the range holds it yet: survey it yourself if the change includes it. Outside git it refuses with
`range_needs_git`, and a REV git resolves to no commit refuses with `unknown_revision`, naming it under `revision`.
Each listed Markdown file, except those under `possibly_test_data`, gives its `outline`: its headings in order, as
Markdown, outside code fences, and under each its top-level list items, an item by its bold lead or its first 60
characters, at most 20 a heading. One with frontmatter gives its `description` too, and leaves the frontmatter
out of its outline. `opening_line` is the file's first prose paragraph, its hard-wrapped lines joined, outside
headings, lists, tables and code, ending at its last sentence end within 160 characters, or else cut on a word. Read
the outlines for the survey rather than the files, so you need no script to take headings out of them. The question
then asks you to name, under the table, the files that look ticket-local or boilerplate.
The result keeps to a byte budget under Claude Code's inline limit for a tool result, so it arrives inline rather
than as a saved file, each file's entry on a line of its own. Past the budget, it cuts one file at a time, making
each cut across the files before the next: a `description` over 300 characters ends at a sentence end, then `(N more
characters, lines A-B)`; then list items; then headings below the second level fold into the one above; then a described file's
`opening_line` is left out; last, a file prints its path and size alone. Described files go first, then the deepest.
The root CLAUDE.md and AGENTS.md go after every other file, and keep their outlines. `outlines_cut` names each file
whose outline lines were cut; a file whose only cut is its description is not named, since its text says so. Under
each heading of a cut file, `(N more, lines A-B)`, or `(N more under M headings, lines A-B)`, says how many items
its section held and which lines of the file hold it, so read just those lines where the survey needs them, not the
whole file. `outlines_left_out` names files at path and size alone. Run `show-candidate-outlines PATH...` for needed
outlines; request fewer paths if it omits any. Root CLAUDE.md and AGENTS.md keep outlines even past the budget.
In git, `untracked` names each listed file git does not track, and
each file a listed link leads to that git does not track: it loads into context all the same, but start-audit
refuses a member in it, or read through a link to it, until the file is committed, so ask the project's
owner before mapping one. `ignored` names each file in those places that git ignores, by any ignore file, a global
one included; this tool does not list it to map, and the host may still load it, so ask the owner whether a rule lives
only there. A folder git ignores as a whole is named once under `ignored_folders`, with how many such files it holds,
rather than file by file. Outside git, `untracked`, `ignored` and `ignored_folders` are left out, since nothing
checked them.
A listed symbolic link gives `symlink_to`, the file its links lead to: two names with one `symlink_to` are one file,
which this list may not name. A skill's `SKILL.md` spelt otherwise, as `skill.md`, gives `skill_file_spelt`, its name;
a case-sensitive host may not load it.
