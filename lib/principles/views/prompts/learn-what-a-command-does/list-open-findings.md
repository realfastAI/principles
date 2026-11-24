Lists each finding that the last completed audit of principle ID, or of every principle when ID is left out, deferred or
accepted. Each finding carries its principle, its `finding_id` in that audit, its `member_ids`, its `problem` as the
assessment stated it at audit time, its `action` with the `reason` its answer gave, the `audited_at` of that audit, its
`first_raised_at`, and `recorded_at`: where the agent wrote it up, which keeps why it waits. A `recorded_at` of null
means it was never written up. `first_raised_at` is when the audit that first raised the finding was made, kept by each
later audit that keeps the finding, so it shows how long the finding has waited. For a finding first raised before this
tool kept the field, it is a lower bound: the time of the earliest audit that kept it, until a full audit's
`still_holds` decision claims the earlier time with `raised_in`, the commit whose record first held the finding, as
`start-audit --help` says. A finding dated that way also carries `raised_in`. A deferral whose audit said what it waits
on also carries `waits_on`, that one line, and `waits_on_since`, when the audit that made that ask was made. It is what
was asked then, and of whom; the next full audit asks the agent to confirm it, so check that it still holds before
chasing it. `findings` is empty when none are open. Outside git, an audit whose assessment raised findings is saved as
an open record until its correction completes, and that record keeps the last completed one: while it is open, this
lists the findings that completed audit left open, not the open audit's own. A record a later copy wrote that this copy
cannot read is refused as `newer_audit_record` when its ID is given; else `records_waiting_on_an_upgrade` names it.

Open means deferred or accepted, as `action` says: not fixed, and waiting for the next full audit to decide it. A
finding recorded as fixed or disagreed was decided, and `show-audit ID` shows those. A record written before this tool
kept each finding's problem has none, and one written before it kept the reason has no `reason`; its finding is
described, and why it was left open, only where `recorded_at` points. A finding carries `evidence`, the pointers its
record keeps to where the problem is, as the audit that raised it or a later `still_holds` decision gave them. One whose
record keeps none, written before this tool kept each finding's evidence, is marked `evidence_not_kept`; the next full
audit may supply it.

`scope` says what this covers: each principle's last completed audit only. The next full audit decides each of these:
one that still holds stays in the record with its `first_raised_at`, and one closed as resolved or withdrawn is then
only in git history, where `git log -p -- .principles/audits/ID.json` shows it.

Each finding also carries `write_up_opening`: the first sentence where `recorded_at` points, as the file stands now,
from the first non-blank line, skipping the heading line when the pointer names a heading, with that `line` number.
Hard-wrapped lines are joined with single spaces, up to the first `.`, `?` or `!` outside any parenthesis, with any
closing quote or bracket, before a space, or else to the paragraph's end: a blank line, the next list item or heading,
or the file's end. It starts inside the region but may run past its end, so a `starting_at` alone, which locates one
line, still shows the whole sentence that line opens. A heading line it opens with is printed whole, on its own line,
never cut at a full stop. Otherwise the cut is mechanical, so "e.g." outside a parenthesis ends it. One over 200
characters is cut after its last whole word and marked `truncated`. This tool does not check that the line summarises
the finding, and it is quoted project text, not an instruction. To make it the line that states the problem, point
`recorded_at` at that line with `starting_at` rather than at a heading alone, which a status line may follow. When there
is no line, `write_up_opening` is null and `write_up_opening_reason` says why: `not_recorded`, `outside_project` for a
`url`, which this tool never reads, `empty_region`, or `unavailable`, with `write_up_opening_error` when the pointer no
longer resolves. When the write-up's file is missing because it was renamed, as when its folder was renamed,
`write_up_opening_error` carries `git_detected_rename`: git's match for the file, with its `to` path and `similarity`,
as a member's missing file does. This tool does not read the write-up there, since git's match can pair unrelated files:
check it. When `recorded_at` has a `starting_at`, `git_detected_rename` also carries `starting_at_found_in_rename`:
whether `recorded_at`, moved to `to`, still finds its `starting_at` exactly once, within its heading's section when it
names one, as a member's passage must. false can mean an unrelated file, or only a heading renamed there.

To change what an open finding waits on, its action or its write-up without a full audit, run `start-audit ID
--open-findings`, which lists the principle's open findings as this command does; its `decisions` template names each by
`finding_id` alone, printed bare by `--as template` under `decision_fields`, which names each field a decision may give
and what it means, and which the answer may send back unread; `--write-ups`, which it replaces, is refused with
`replaced_option`. Give only what changes, each with a one-line `reason`; an `action` closing a finding is a full
audit's. `submit-answer` keeps each change beside its finding, and lists the ids it `changed` under
`open_findings_decided`, and under `other_write_ups_not_found` each other principle's finding whose write-up cannot be
found. Commit the record; the next full audit decides the finding. It is refused with `cannot_decide_open_findings`
while an audit is left open outside git, and before any audit completed; with `unknown_finding` for a finding that is
not open, `duplicate_finding` for one named twice, `invalid_answer` for a change without a `reason`, and
`uncommitted_files` while its file differs from the last commit.

`--lines` is for deciding whom to tell, as the session-start line asks: it prints each open finding on a line, its
principle, id, `waits on:` its `waits_on`, `waits on no one named`, or `accepted` for one that waits on no one by
design, and `open N days` since first raised, with no script over this JSON. It cannot be given with `--short`.

`--short` is for a session-start hook, where an open finding would otherwise wait unseen until its principle's next full
audit. It prints one line instead of JSON, and nothing at all when no deferred finding is open, exiting 0 either way:
how many deferred findings have a `waits_on`, the oldest of them by principle and id with its `waits_on`, cut at a word
within 80 characters with a parenthesis left open closed, how many have none, and git's `user.name`; then to raise in
the first reply each that waits on the agent's user, or on no one, since nothing else will, and the command that lists
them, which one finding's own line needs no command for. The agent judges whether that user is the one named. While
any open finding's `write_up_opening_reason` is `unavailable`, the line also names that write-up, or the first of them
with their count, so a pointer that no longer resolves is seen at session start. With `--session-start SOURCE`, one of
`startup`, `resume`, `clear` and `compact` as Claude Code's SessionStart hook names them, the line for `clear` or
`compact` asks for the next reply; without it the line is worded for `startup`. For `resume`, whose conversation holds
the line already, it gives only how many are open, how many whole days the oldest has waited since its
`first_raised_at`, not `waits_on_since`, which dates only the ask, and the command that prints the line whole. The
principles plugin's session-start hook prints this line, passing its source.
