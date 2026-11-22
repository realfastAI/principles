Checks each member of principle ID, or of every principle when ID is left out, against its baseline: the
last audit's hash for it, or else its text at the commit that mapped it where it is, so committing an unrelated change to the map does not hide a change to it.
A member counts as changed only when its own text changed, so an edit elsewhere in its file is not listed.

It refuses with `broken_members` while any member cannot be found or read, or a map cannot be read. So a project's
own check can stop on its exit status. Each member the refusal lists carries its own refusal and `repair_with`: a
`move-member`, if it moved; for a section or passage, a second `move-member --path NEW_PATH`, if its text moved into
another file; or a `remove-member`, if it is gone. When its file was renamed, the move is `move-member --path
NEW_PATH`, which keeps its audit. `missing_files` groups the members of each file that cannot be read, with
`git_detected_rename` when git pairs that path with a file: its `to`, `similarity` and `deleted_in`. That is git's
match, so check it before you fill in `NEW_PATH`.

Otherwise it lists each changed member with `since`: whether it was compared with the last audit (`audit`) or with
the commit that mapped the member where it is (`mapping_commit`), and that commit, and `history`: the commits after
which the member's own text differed, newest first, given with `--history`, and `stopped_at`: where the walk ended.
It ends at the first commit whose text matches the baseline, so a fix an audit already took in is not listed. It
follows a member that `move-member --path` moved to a renamed file. A merge is compared with its first parent. `uncommitted` says whether the text on disk differs from HEAD.
`compared_with` counts each principle's members by baseline, `no_baseline` among them, and `counts` holds every state:
`unchanged` for a member as its last audit or acknowledgement recorded it, `unchanged_since_mapping` for one compared
only with the commit that mapped it, which no audit has assessed, and `no_baseline` for a member with no earlier text.
`no_baseline_because` says why, for each principle with one: `outside_git`, where no completed audit assessed it,
so a completed audit gives each one; or `not_committed`, where no commit holds the member where its map places it,
so committing those of the map and the member's file that differ from HEAD or are untracked gives it one,
and when every one is committed already, a completed audit gives it one. `next_action` names that audit, or those
files.
`no_completed_audit` names readable maps without a completed full audit, even uncommitted. `next_action` counts them
before baselines without judging meaning or completeness. `empty_maps` names maps with no members, even after an audit.
Add a member first if empty; commit required files before an audit. Unknown/newer records keep upgrade/refusal guidance.
`awaiting_first_audit` retains its baseline prerequisite: in git a commit holds the map or an audit is open;
outside git the audit supplies the baseline. Audited maps' added-member lines remain.
This tool compares text, not meaning. When a change alters what a member says, or its check changed, run a full
audit with `start-audit ID`. When the member still says the same thing, a completed full audit has judged it and ran
its check, if any, in git, acknowledge it with `start-audit ID --member MEMBER`; `next_action` offers that only where
it applies, as one command per principle giving `--member` for each such member, quoted for a shell.
`records_waiting_on_an_upgrade`: principles whose record a later copy wrote, changes marked `waiting_on_an_upgrade`.

Run it after a commit that touches a mapped member's file, and at the start of a session.

`--short` is for a git hook or a heartbeat that acts on an exit status and short lines alone. It prints one line per
changed member on stdout, with these tab-separated fields: its principle, its id, the newest commit that changed it
(or `uncommitted`), whose subject and earlier commits `--history` adds to the JSON result, and what it was compared
with: `audit` when an audit or acknowledgement assessed its text, or `mapping_commit`
when no audit has, so only the commit that mapped it gives a baseline, then `waiting_on_an_upgrade` for one compared
with hashes a later copy wrote. Members compared with an audit come first. Control and invisible characters in a field
are written as `\uXXXX`, so an id holding such a character is escaped for display: copied from a row, it names no
member. The commands `next_action` prints carry each id exactly. After the rows, a line for each principle with members
no audit has assessed gives its id and `N never assessed`. It exits 0 when no member this copy can act on changed, as
when each change waits on an upgrade, and 3 when it prints a row or a count.
Every refusal exits 1 with a single line of JSON on stderr, the only line this tool writes there when it refuses,
whose `code` names it, such as `broken_members` (a member that cannot be found or read), `principles_folder_not_moved`
(a project state to repair) or `unsupported_ruby` (no supported Ruby runs this tool). Other programs, such as an rbenv
shim, may write other lines there, and codes may be added: a code a hook does not know is still a refusal to read. A
usage error exits 2. When it does not refuse, stderr carries what to do next, its commands naming `--project` if given
it, else run in the project it names once, and says when there are no maps, or members with no baseline, that an empty
stdout would hide. A changed member stays listed until an audit takes it in: a notice, not a gate that blocks commits.
For a post-commit hook, run: %{executable} list-member-problems --short || true
A heartbeat can compare each line's commit with the last one it reported.
`--short --session-start SOURCE`, for the session-start hook, prints one line instead: a changed principle's count
and this command for it, to run before the user's task, or, for several, their count and `--short`, which lists them.

`--commits-after COMMIT --hook-event EVENT` is for a Claude Code hook that runs after a Bash call, so a long session
learns of a member it changed at the commit that changed it, not only at its next start. The plugin's after-commit
hook runs it once HEAD moved during the call, with COMMIT the full sha HEAD pointed at before, and EVENT the hook's
event, `PostToolUse` or `PostToolUseFailure`. It prints one JSON object, `hookSpecificOutput`, whose `hookEventName`
is EVENT and whose `additionalContext` names, one row per member in `--short`'s fields, the members whose newest
changing commit came after COMMIT, of both kinds, then how many other changed members are still listed, this command
without the options, and, under the plugin, a line naming the `/principles` skill as where to start; one waiting
on an upgrade comes apart. It prints nothing when those commits changed no mapped member. A refusal is reported, as
its code and this command, only when those commits changed `.principles/` or a file a map names, since only then could
they have caused it; else it prints nothing, and the session-start hook reports it. It exits 0 but for a usage error.

A member edited without changing what it says is listed at every commit until an audit takes the edit in. A member still
says the same thing after a fixed typo, a reworded sentence or a renumbered citation; an added, dropped, reversed,
narrowed or widened rule changes what it says. When one member was edited but still says the same thing, and a completed
full audit has judged it, take in just that edit with `start-audit ID --member MEMBER` instead of a full audit.
