Shows the record of principle ID's last audit: whether it is open or completed, the commit it began
from, each member's hash and each finding's members and disposition. Run it when a completed result
points here with `full_record`.

When you need only what the last audit found, as when filling a full audit's `recent_decision`, add
`--findings`: it prints the record's `principle_id`, `status`, `base_commit`, `audited_at` and `findings`
alone, without the members it judged, and for an open record the same of the last completed audit it keeps,
under `last_completed`. `base_commit` is the commit the audit began from, whose text its findings'
evidence names; the fix of a fixed finding landed after it. A completed record keeps no `last_completed`,
so an earlier audit's findings are then only in git: git log -p -- .principles/audits/ID.json shows them.

A full audit keeps each member's `assessment` as you gave it: the `assessment`, `delivery`, any
`observation` and the `evidence`, with `evidence_sha256`, the hash of each evidence item's text then,
`assessed_at`, and `entry_sha256` and `loads_sha256`, digests of the member's map entry and of when it
loaded. An observed delivery also keeps `observed_at`, when its sighting was: the time you gave, or else
`assessed_at`; a record written before sightings were dated has none. `judged_against` digests the principle's description and the question the audit asked. A member
the audit's correction changed is shown with `changed_during_last_audit` and no assessment, since none
read its fixed text. A record written before assessments were kept holds none.

A member with a check also shows the `check_result` the agent reported for it, as of that commit:
the command and its exit status, or why it was not run. This tool never ran it, so the record shows
what was reported, not proof that the check passed. Beside a run check, `review_basis` says what the review
before it rested on, and `review_basis_since` when an audit first kept that line; this tool never checked it.

An ID that has no record is refused as unknown_audit when a map names it, with the audit to start, and as
unknown_principle when none does, with the commands to create or list principles. A record kept after its
map was removed still shows. A record a later copy wrote, at a format this copy cannot rewrite, also shows
`record_waiting_on_an_upgrade`, saying its audits and acknowledgements wait on an upgrade, and how to update.
`list-principles` gives that field as the record's format alone, and says how to update once, in `next_action`.
