A finding kept from records written before this tool kept `first_raised_at` is dated late. When the record's git
history shows an earlier version leaving it open, at `.principles/audits/` or the folder's earlier name
`.memeplex/audits/`, and you judge it the same finding, give `first_raised_at`, that version's `audited_at`, with
`raised_in`, the full sha of the commit holding it, in its `still_holds` decision. This tool reads the record at
that commit only, and refuses the claim unless that version leaves a finding with the same id deferred or accepted,
its `audited_at` equals the claimed time, and the time is earlier than the one stored; whether it is the same
finding is yours to judge.
