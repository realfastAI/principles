Address each finding with an authorised edit, or record it as deferred, accepted or disagreed. The
template leaves each `action` as a placeholder: set it to fixed, deferred, accepted or disagreed for each finding. A
fixed finding needs an actual change to its members, evidence and a reassessment. Replace each placeholder the
template gives a `reason` or a fix's `reassessment` with your own words, and do not copy an `answer_guide`
sample into the field it illustrates, `waits_on` included; either one sent back unchanged is refused. Keep the project's
owner-approval process; this tool edits nothing. The audit record keeps each finding's members, its
`problem` as you stated it and its disposition, but not your reason. So when you write a finding up somewhere the project keeps, such as a ticket
or a notes file, set its `recorded_at` to that place, as `{"path": ..., "heading": ...}` or with
`starting_at`, and the record keeps the pointer in the record. Leave it null when there is nowhere to point. `list-open-findings` prints the first non-blank line where `recorded_at` points, so open a write-up with one line saying what the finding is. Point with `starting_at` at the line that states the problem, rather than at a heading alone, since a heading is often followed by a status line or is shared by several findings.
When a deferral waits on someone, set its `waits_on` to one line saying whom it waits on and to decide what, such as
"<person>, to approve a CI change", and keep the reason in the write-up. Leave it null when it waits on no one in
particular. Only a deferral may give one, and this tool records when it was asked.
If a fix rewrites the heading or the quoted text that locates a member, or the member's passage should be narrower
or wider, move the member with `move-member`, then list the move in the answer as
`"moved_members": [{"from": OLD_ID, "to": NEW_ID}]`, or `[{"from": ID, "to": ID}]` when the move kept its id, and
name the id after the move in the finding's `changed_members`. In git, the move is checked against the map
the audit began from.
If the fix is to a member's role or check in the map, make it with `change-member-role` or `change-member-check`
and list the member's id in the finding's `changed_map_entries`. In git, the change is checked against the map the
audit began from.
If the fix is to map a member the finding says is missing, add it with `add-member` and name its id in the finding's
`changed_members`; it needs no other declaration. In git, this tool accepts it as long as nothing else in the map
changed. No assessment has read it, so the record gives it no baseline: the completed result names it under
`members_added_awaiting_assessment`, and the next full audit assesses it. Outside git, a member added now is refused:
defer the finding and add the member after the audit.

If the fix removes obsolete guidance from the map, use `remove-member`, keeping its source file, then list its
original id in that fixed disposition's optional `removed_members`. In git, the union of those lists must explain
exactly the map removals; repeated claims are allowed. Each removed id must exist at the audit base, be absent now,
and appear in neither `moved_members` nor `changed_map_entries`. `changed_members` names current text changes; leave
it empty for a removal-only fix. Give a substantive reassessment and at least one located evidence pointer about
the remaining guidance for a fix with only removals. This tool checks the pointer, while you judge its relevance.
Leave a survivor or add a replacement; a new member still awaits assessment. Existing findings keep their original
member attribution and age even when their member was removed. An empty endpoint cannot complete this correction:
retain the correction packet and restore the map entries before reconsidering or deferring, or explicitly deactivate
the principle while retaining its previous audit history. A removal grants no permission to delete a source file.
Non-fixed dispositions omit `removed_members` or leave it empty. Without git, map removals cannot be verified.
