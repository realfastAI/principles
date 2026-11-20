Each open finding in `findings` has its `recorded_at`, and what list-open-findings says of the write-up there: its
`write_up_opening`, or why there is none in `write_up_opening_reason`. When the file is missing, git's match for it is
in `write_up_opening_error.git_detected_rename`, with `starting_at_found_in_rename` when the pointer quotes a
`starting_at`. Git's match can pair a deleted file with an unrelated similar one, so read the file it names before you
use it. For each finding whose write-up you found, set its `recorded_at` in `repoints` to where the write-up is now,
as `{"path": ..., "heading": ...}` or with `starting_at`, and give a one-line `reason`. Leave `recorded_at` null for a
finding you do not repoint. Only `recorded_at` changes: the finding stays open, with its problem, action and dates,
for the next full audit to decide. During a full audit, give the new `recorded_at` in that finding's still_holds
decision instead, since a repoint changes the record that audit's request was printed after. Do not edit the audit
record by hand: nothing would check that the new pointer is found.
