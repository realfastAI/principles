Adds PATH to principle ID, with ROLE saying the part it plays, such as "states the principle" or "fails
the build". Add one member per command. The result names the member it added under `added`, and how many the
map now holds as `member_count`; `show-principle ID` lists them all. ID must be mapped already, except
`sticking-to-your-principles`: while it has no map, its first add-member creates the map, with the description
and activation `show-meta-principle-passage` shows, and that member. That result names the description and
activation it wrote under `map_created`; a later add-member has no `map_created`. Its question says to commit the map,
how to show it, what to do next and, while a correction may be open, how a fix claims the member, only with a
principle's first member or, in git once it has a commit, while the map file is as last committed, so members
mapped in one sitting do not each repeat them. `--plugin NAME@MARKETPLACE` maps PATH inside an installed
plugin, whole and read-only, refusing a location flag (`plugin_member_located`); audits compare its pinned hash.

The location flags narrow the member; omit them for a whole file. Give both to take a passage within a section:

- `--section HEADING`: a Markdown heading's exact text without its # marks. The section runs to the next
  heading of the same or a higher level.
- `--starting-at TEXT`: one literal opening; without `--ending-at TEXT`, the passage ends at its line's end.
  In Markdown, `added.continues_to_line` is the last line of a paragraph or list item that runs on past it.
  A new literal ending must occur once after the complete opening in the selected region; overlapping matches count.
  `ambiguous_passage_end` refuses before writing, with exact `eligible_ending_count`, up to five `ending_candidates`
  (1-based line/character column), and `ending_candidates_omitted`. Quote more specific closing text.
  Existing stored members and evidence use the first ending with unchanged hashes; only new add/move is stricter.
  The member's id ends with `@TEXT`; `change-member-role` and `start-audit --member` take it.
  This tool quotes it in each command it prints. For manual typing, choose short TEXT without backticks, quotes or `$`.
- `--query '$.FIELD'`: one top-level field of a Markdown file's frontmatter, such as `$.description`,
  which is what makes a skill or subagent load. A query is standard JSONPath, so a name with a hyphen
  goes in brackets: `$['allowed-tools']`. The member is the field's lines as the file writes them:
  its `key:` line and the indented or list lines after it. So respelling the key counts as a change,
  as does editing its value. A query takes no other location flag.

`--check COMMAND` names the command that enforces this member, such as the build task that fails on a broken rule.
Each audit asks you to run it and report its exit status. A check passes when it exits 0 and fails on any other exit
status. The first audit after a check is added or changed asks for it to be reviewed before it runs. This tool
stores the command and never runs it. Change it later with `change-member-check`.

If the keeping principle's map was removed, commit that removal before its first add-member recreates it.
`map_removal_not_committed` refuses while its map is at committed HEAD, `git_history_unavailable` when unverifiable.

When one or two members are mapped and this copy knows no full audit has completed, that reminder asks whether
every carrier is included and whether a member belongs to another principle. This is a question, not a minimum
map size or a merge decision; unreadable/newer audit state does not count as known absence.

`added.new_loading_scope` appears when this member has known literal loading-scope qualifiers not already mapped,
and at least one prior known scope differs. `scope` and `already_mapped` (grouped `member_ids`) show the new and
prior facts. `loading_basis` is `host: claude_code`, `kind: documented_prediction`, `session_start_assumption:
project_root`; it is not observed delivery or a Codex derivation. The question asks whether carriers will be
available where the principle applies, or should link to another carrier. This cue does not depend on audit history
or the per-sitting reminder; adding another member in an already represented scope does not repeat it.
The projection keeps when, context, invoked_by, skill_part and description qualifiers, with literal files and
paths_field lines in their original order; it excludes sizes and hook references and does not interpret globs.
`not_loaded` is a known no-load prediction. `not_determined` and `no_known_carrier`, even nested, are unclassified:
`not_compared` lists each unclassified `member_id` and `scope` only beside a positive hint, never as evidence
of equal scope, difference or delivery. Unknown new scopes or only unknown prior scopes give no new-scope field or cue.

`added.consecutive_sections_elsewhere` names other maps' members in consecutive complete Markdown sections of the
same underlying file (heading locators alone, meeting without overlap or gap), with path, role and current lines,
only while every named map lacks a completed full audit. The question asks whether they carry one rule or distinct
principles; location alone does not decide. Unreadable or unknown audit or member facts are left out.

`added.whole_file_elsewhere` lists other principles holding the new whole-file member's file whole, by path or link.
`added.member_sets_overlap` gives each other map sharing, by member id, the new member and one more, `shared`, and at
least two thirds of `members_in_either`. Either asks whether each should hold only the passages that carry it
(move-member) or they are one principle: add one map's members to the other, then remove-principle.

When the new member shares a line with members already mapped, `added` names them, so you see that one edit there
will show as a change to each: `overlaps` lists those in this principle, and `mapped_elsewhere` those in other
principles, each with its principle, its id, its role there and its `first_line` and `last_line`, which this page
does not otherwise show; one mapped through a symbolic link to the same file is listed under the path it was mapped
by. Check that the role you gave fits beside theirs. A member spanning exactly the new member's lines is marked too:
in this principle by `same_lines_as`, listing those of `overlaps`, and in another by `"same_lines": true` on its
`mapped_elsewhere` entry. Equal lines may still differ within a line, so decide whether they are one member mapped
twice under different ids, and keep one, or two meant to share those lines, and say why in the role. A
`mapped_elsewhere` entry whose lines include all of the new member's gives `"spans_these_lines": true`, and one whose
lines all lie within the new member's gives `"within_these_lines": true`; one sharing only some is marked neither way.
Every edit to the held member's text is an edit to the holding one, and an edit outside the shared lines reaches only
the holding one. These are lines, not text: where two share a first or last line, a passage can start or end partway
through it, so the question asks you to check the text there, unless the holding member is a whole file, which holds
every line's text. Each field is listed only when there are some.
