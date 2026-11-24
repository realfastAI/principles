Checks your answer, to the request its `request_id` or REQUEST_ID names, as `submit-answer` would; writes nothing.
It prints the refusal `submit-answer` would give, such as a passage that matches twice, or `answer_acceptable`
with the files submitting would write. Use it instead of searching the project yourself before you submit. Pass
`--file FILE`, naming the answer written to a FILE kept out of git; `--file -` reads it from stdin instead.
Its `next_action` ends with `submit-answer`, giving the same `--file` value again.

The same current-ID history checks apply to assessment/correction answers with a Git base. For their
`stale_request` and `git_history_unavailable` conditions and repairs:
%{executable} submit-answer --help

For a correction removing obsolete guidance from the map, each fixed disposition may give `removed_members`:
the original member ids actually removed with `remove-member`, leaving source files intact. The declaration is
checked against the original Git map. `invalid_removed_members` refuses unknown, still-present or conflicting
claims; `empty_correction_map` refuses a result without a survivor or replacement. A removal-only fix leaves
`changed_members` empty and supplies a substantive reassessment and located evidence about remaining guidance.
Restore entries before reconsidering or deferring an emptied map, preserving the unsubmitted correction packet;
explicit deactivation retains previous audit history. This preview never writes. The correction question and its
answer guide give the full declaration contract, including repeated claims and exact Git map reconstruction.

When the answer would write a record that keeps findings open with a write-up, `open_findings_will_print`
names each by `finding_id` with what `list-open-findings` will print for it as its `write_up_opening`, its first
sentence with hard-wrapped lines joined, or null with the reason. If that line is a bare heading rather than the finding, move the write-up or the
pointer before you submit. Nothing is shown until an answer writes a record, so in git a full audit's
first appears at the answer that completes it.

When a full audit's assessment carries a member forward whose kept assessment names a finding the answer decides
other than still_holds, `carried_assessments_citing_decided_findings` lists it with those `finding_ids`, as a fact
to judge before you submit: ids repeat across records, so nothing is refused.

When a full audit's assessment sets a prior finding's `recorded_at` to null, `prior_findings_pointers_dropped`
names each finding whose write-up pointer that drops, with the pointer, so you confirm the drop is meant.

When a deferred finding the record keeps open gives `recorded_at` null, `next_action`'s first line names it: null
is allowed when there is nowhere to point, and then `list-open-findings` prints no write-up for it.

When a full audit's assessment has findings, `next_action` names the command that prints the correction's answer
it leads to, `--as template`, with its `request_id` and the `basis` digests filled in, so you never copy them by
hand; `show-open-correction ID` prints the same answer once the assessment is submitted. Redirect it to the file
`next_action` names by its full path, kept out of git, and fill only its `dispositions`: each `action` names the four actions,
and the answer guide shows what each adds. Submit it after the assessment, as `next_action` says; the assessment writes the open record the
correction is checked against. `--as template` refuses with `no_correction_to_fill` an answer that leads to none.

`correction_recovery` says to keep a copy of the assessment you submit, or for `--file -` its exact stdin bytes,
until the correction completes the audit, and ends with `show-open-correction ID`, which prints the correction's
answer again from the open record once the assessment is submitted, in git or outside it and after fixes too.

When a correction's fixed disposition lists `changed_map_entries`, `map_entry_changes` names each such member by
`member_id`, under its id after any `moved_members`, with each of its `role` and `check` that changed since the
audit began, as `was` and `now`; a removed check is `now` null. Read it before you submit: a change listed that
you did not mean to make is a reason to undo it, not to claim it.
