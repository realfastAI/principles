The last completed audit deferred or accepted the findings in `prior_findings`. Decide each one in
`prior_finding_decisions`, and do not raise it again as a new finding unless you decide `raised_again`. Each one
carries its `problem` as that audit stated it, its members under their ids now, and `members_since`: whether each
member is `current`, `changed` or `removed` since that audit. Read its write-up where `recorded_at` points when
there is one. A finding marked `text_not_kept` has no statement; judge it from its members.

Decide `still_holds` to keep it. Give `recorded_at` to point at a new write-up, and `problem`, one line, when the
finding is marked `text_not_kept` or to restate its problem when a term in it was renamed or a fact it names moved,
since a different problem is a new finding; the record keeps its `first_raised_at`, so leave that field out unless an
earlier record held the same finding; to claim that, read this field whole.

To change its `action`, give `action`, `deferred` or `accepted`, with a one-line `reason`. A deferral also gives
`recorded_at`, or null when it is written up nowhere; a null drops any pointer the finding had, and the completed
result names it.

Decide `resolved` or `withdrawn` with a one-line `reason` to close it. A `resolved` decision may also give
`evidence`, pointers to where the fix shows, which must resolve.

Decide `raised_again` with `as` set to the id of a new finding in this assessment when you will fix it in this
audit, which keeps when it was first raised. Two raised again as one new finding are refused: to merge them, raise
one again and close the others as `withdrawn`, with a reason naming the new finding.

A new finding may not reuse the id of a prior finding you keep. The prior findings are %{ids}, so give new findings
other ids.

A `still_holds` decision may give a deferral without one its first `waits_on` line, saying whom it waits on and to
decide what; its `waits_on_since` is then this audit, while `first_raised_at` keeps how long the finding has waited.
