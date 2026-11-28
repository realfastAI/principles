Asks you to assess every member of principle ID and the set, after mapping or when `show-principle` reports one changed
or unassessed. `--part PART` prints parts, sized in `part_bytes`: a member's with `text` and `lines_in_text`, or a whole
file's `text_part`: `read_with`, `bytes`, `read_whole`; `response_template` bare or `part_empty`; `--as template --part
members/ID` slots. `--part index`: `part_command`, `bytes` or `bytes_unknown`, `this_audit`: `judges` (ids: `--part
judged_members`)/`carries_forward`, `trimmed_instructions`, `answer_with` and `next_action`, per `read_in_parts`.

`start-audit` itself writes nothing. `submit-answer` writes the audit record, `.principles/audits/ID.json`: a full audit
writes it open when its assessment has findings, completed once it has none or its correction is accepted. In git,
commit each completed record, as `files_to_commit` lists it. In a full audit, make each fix after the assessment is
accepted and before you submit the correction that reports it, or the assessment is refused as `stale_request`, as is an
edited `basis`, whose `basis.last_completed_revision` names the record it follows. The audit judges the text now: a
problem no completed audit recorded and fixed before `start-audit` is not recorded, and a deferred or accepted finding
fixed since is decided `resolved`. To record one, commit a revert, run the audit, and redo it in the correction.

It refuses with `broken_members` while a member cannot be found or read, by file in `missing_files`. A checked member
carries `check_since_last_audit`, and `check_hidden_characters` if its check hides any. `mapped_elsewhere` shows other
principles' members on its lines, judged by `mapped_elsewhere_instruction`, with `open_finding_ids` from
`open_findings_elsewhere`, whose `evidence` items say `shares_lines_with`, `shares_no_lines`, `whole_file` or
`not_located`, or which says `evidence_not_kept`. In git, `context.uncommitted_files_outside_the_map` lists up to ten
changed or untracked files, `not_named` the rest. A meta-principle audit adds `package_since_last_audit`,
`passage_changed` and `other_principles_with_unjudged_changes`. `logged_requests` shows what captured requests hold.

After a full audit, a member carries `carried_forward`, its `assessed_at`, an observed one's `observed_at` (or
`observed_at_from_assessed_at`), `evidence_changed` and, in git, `file_changed_outside_member`, or `judge_because` with
`read_the_change`, a whole file's text change `changed_lines`, a moved one `moved_from`; a carried one prints whole if a
fact fires; `carried_forward_instruction` and `judge_because_instruction` explain. One acknowledged since carries
`acknowledged_since_last_audit` with `last_audited_commit`, its acknowledgements, lines then and now, or, once moved,
`not_found_at_last_audit`. A new or changed check needs `review_basis`, kept unverified; an unchanged one `review_basis`
and `review_basis_since`, kept if left as printed, a changed one `last_run_review_basis`. A plugin member has `source`.

## Prior findings

When the last completed audit deferred or accepted findings, `context.prior_findings` lists them, with `action`,
`reason`, `first_raised_at`, `waits_on`, `waits_on_since`, changes since as `changed_since_audit`; older ones may claim
`raised_in`. Each listed finding shows its `evidence`, in git each item with `changed_since_last_audit` and `found_now`,
or `evidence_not_kept` and an `evidence_request` for `problem_evidence`, whose `replaces` re-points a lost item. Decide
each in `prior_finding_decisions` as `still_holds`, `resolved`, `withdrawn` or `raised_again`; only `resolved` may give
`evidence`. `--as template` adds each `finding_problem`. Results name `prior_findings_pointers_dropped`,
`prior_findings_waits_on_dropped`, `prior_findings_evidence_replaced`, `prior_findings_problems_restated`.

## Members to check against the activation

When the principle's activation is a set of files, `context.loads_to_check_against_activation` lists each member whose
file Claude Code loads at session start, with its `loads` and `listed_for`, for you to weigh; this tool compares no
globs, and `not_listed_no_known_carrier` names those with no known carrier. Decide each row in `loading_decisions` as
`context.loads_to_check_instruction` explains, or it is refused as `incomplete_loading_decisions`. An accepted decision
is kept as `loading_accepted`, which the next audit shows as `last_accepted`, with `last_accepted.since_accepted` and
whether `member_text` or `loading` changed. Not listed yet: members loading on files, skills or agents, ones a hook
names or this tool could not determine, and any under an invoked or always activation or in a one-member audit.

## One member's edit: `--member`

Use `--member MEMBER` when one member was edited but still says the same thing, as `list-member-problems --help`
describes. It shows `baseline_commit`, `member_lines` (or a large member's `changed_region` or `changed_regions`,
`context_lines`, `from_line`, `unchanged_lines_skipped` or `read_instead`), `first_changed_lines`, `read_the_change`,
`check_instruction`, its `deferred_findings` and `accepted_findings`, with `deferred_findings_kept` and
`change_shown_under` across principles; its `question` asks for `meaning_kept`; `--as template` adds `role` (or `roles`)
and `answer_with` to read. This tool checks both quotes. A near-miss id gets `unknown_member` and `did_you_mean`. A
one-member audit writes the record once its answer is accepted, keeping the edit in `acknowledgements`; commit it. It is
refused as `cannot_acknowledge` outside git, while an audit is open, and for a member no completed audit assessed, whose
baseline text does not match the audit record, whose check is not the one that audit ran, or whose `check_result` is not
a pass: run a full audit. A member moved with `move-member` since its baseline carries `evidence_at_baseline`, and one a
full audit's correction fixed carries `audit_base_commit`: judge only the change since `baseline_commit`.

## Outside git

Outside git, the open record also keeps what the audit began from and, until its correction completes, prior findings.
