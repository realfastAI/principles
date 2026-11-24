Gives your answer, filled from its template, to the request its `request_id` names; a REQUEST_ID you give must
match. Pass a JSON FILE kept out of git with `--file FILE`; `--file -` reads stdin. This tool writes audit records
at `.principles/audits/ID.json`, never member guidance. In a full audit, make each fix after the assessment is accepted
and before you submit the correction that reports it; earlier fixes cause `stale_request` before an assessment's shape
check. A completed full audit or acknowledgement after an assessment/correction request causes
`audit_completed_since_request`, protecting the newer record and its findings: run `list-open-findings ID`, then start
again. Keep `basis` unchanged; `last_completed_revision` identifies its preceding record. An identical completed-answer
retry writes nothing; an assessment whose correction completed is refused.

After prior request checks, a Git-based assessment/correction expires at a committed current-ID map gap on captured
HEAD's first-parent line (`stale_request`), even after identical recreation; start anew. Unrelated commits are allowed.
Unverifiable continuity (missing history/tree or base off that line) gives `git_history_unavailable`: restore complete
history/access or start a new audit on this branch. Requests with no Git base keep their existing behavior.

An observed assessment may give `observed_at`, the sighting's time to the second (for example `2026-11-01T09:30:00Z`, or
with an offset such as `+05:30`, kept as the same instant in UTC); absent or null uses this audit's time. When the
sighting is a dated record you read during this audit, `observed_at` is the record's date, not when you read it. Wrong
format, dates after the answer or any date on not_observed, even null, cause `invalid_answer`. An observation judged
afresh that copies the last audit word-for-word causes `observation_repeats_last_audit` unless `observed_at` matches
that sighting or is null. Keep its date for a retained sighting; reword a later one, using null for this audit. Reworded
text is not judged. An evidence/`recorded_at` location refusal (such as `ambiguous_passage`) or `check_result` refusal
(`invalid_check_result`) retains its code, any `path` and repair, names whose evidence/check failed, and gives `fields`
with each `problem` and JSON `pointer` into your answer. `invalid_answer` names fields ending in another template's
placeholder; use this template or reword the ending. Set correction `action` to fixed, deferred, accepted or disagreed;
else `invalid_disposition` names the finding. A deferred disposition may give `waits_on`, one line naming whom it waits
on and to decide what, printed by `list-open-findings`. Null is allowed on any action; text on another action or
multiple lines causes `invalid_disposition`. The tool records when it was asked; never send that time. For a legacy
prior finding, `still_holds` may supply `first_raised_at` (that audit's `audited_at`) and `raised_in` (full commit sha)
together. Only that commit's `.principles/audits/ID.json` or earlier `.memeplex/audits/ID.json` is read; it must leave
the same finding deferred/accepted. Judge identity yourself. Refusals explain repairs: `raised_in_not_found` (also
outside git), `raised_in_unreadable`, `raised_in_lacks_finding`, `raised_in_time_differs`, `first_raised_not_earlier`
(date must precede stored time). Completed full audits list own/kept deferred or accepted IDs in `open_findings`,
fixed/resolved IDs in `resolved_findings`, and each closed prior finding's decision/reason in `prior_findings_closed`.
Disagreed/withdrawn findings are in neither open nor resolved. In git, `commits_since_base` lists commits touching each
member's file; uncommitted fixes have an empty list. `files_to_commit` lists their files; `commit_with` commits only
those, stopping during an unfinished merge. Replace its `-m` default as `commit_message_to_replace` says.
`cited_files_missing` lists missing cited files excluded from `files_to_commit`; record references remain. If HEAD moved
without touching a member, `head_moved_past_base` gives `base_commit` and `head`. If its fixes changed a file another
principle also maps, `other_principles_with_changed_members` names each such principle and its members in fixed
findings' files, by `id` with the `state` `list-member-problems` gives: `changed` when its text now differs from its
baseline, or `locator_lost` or `unavailable` when the fix broke where this tool finds it, which its `repair_with` on
`show-principle ID` repairs. Then re-audit that principle, or acknowledge a member's edit with `start-audit ID --member
MEMBER`. A changed file no fixed finding names is not checked. A correction's `next_action` names `show-open-correction
ID`, printing its answer, not in this result, to save, edit by hand and submit. `correction_recovery` says
what to retain; `show-answer-check --help` covers `carried_assessments_citing_decided_findings`.

In git, this tool reads the map at the audit base: fixed dispositions declare roles/checks in `changed_map_entries`,
text/additions in `changed_members`, removals in `removed_members`. `invalid_removed_members` rejects invalid removal
claims; `empty_correction_map` requires a survivor/replacement. Source files stay intact.
`claimed_change_missing` rejects unchanged entries; `members_added_awaiting_assessment` lack baselines.
Role/removal claims require git (`map_entries_need_git`). Full rules: correction question, `show-answer-check --help`.

For a `start-audit --member` request, `quote_not_found` refuses an `old_line` or `new_line` not a line only its side
holds, or "" where `first_changed_lines` is not, and one left out reads as printed; else it prints `acknowledged`.
