Remove an obsolete map after its rules have been consolidated or split using change-description, add-member
and remove-member. The agent decides which rules belong together; this command never merges principles or
transfers findings. It removes only `.principles/maps/ID.json`, leaving member files and audit history alone.

Without `--confirm`, removal is permitted only when there is no current audit entry. That is not a claim
that the principle was never audited: version control may retain older records. Any current entry protects
the map, including an open, invalid, newer or dangling entry; `principle_has_audit_record` refuses removal.

Use `--confirm` only after deciding that this exact map should leave routine active-map reports. Confirmation
removes only the map; it preserves the audit entry byte-for-byte and does not resolve retained findings.
It does not require a readable record, upgrade it or repair a link. Inspect a readable retained record with
`show-audit ID`; invalid, newer or linked entries may require diagnosis before that read succeeds.
An access failure while checking for a current audit entry still refuses even with confirmation.

The result's `status` is `removed`; `principle_id` identifies it. `removed` lists the exact deleted map path,
while `wrote` is empty because no file was written. `next_action` names list-principles. In Git, commit the
removal if the map was tracked; an untracked map's removal needs no Git commit. No Git history is rewritten.
Before recreating a tracked map's ID, commit its removal: creation refuses while that map path remains at
committed HEAD. Once absent there, recreation uses its retained audit record as before; use a distinct ID for a distinct principle.

Missing or invalid IDs refuse without changes. Linked store parents and final map links refuse rather than
unlinking a target. Nonregular entries refuse with `not_a_file`. If access prevents checking for an audit entry, the command refuses with
`store_entry_unreadable`; an entry disappearing after validation or a failed unlink gives `store_remove_failed`. Restore access
or the intended regular file before retrying. This command does not provide an atomic compare-and-delete
against concurrent external edits. A final linked map refuses with `symlinked_store_file`.
