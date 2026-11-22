Each open finding in `findings` is as list-open-findings prints it. For each finding you decide, add to its entry in
`decisions` only the fields that change, as the template's `decision_fields` names them, each with a one-line
`reason`. A field left out keeps its value, so an entry left as printed changes nothing. Closing a finding as resolved
or withdrawn judges the problem against the text now, which is a full audit's work: record an owner's ruling that there
is no problem as `accepted`, with that reason, for the next full audit to withdraw. That audit sees each change under
`changed_since_audit`. Do not edit the audit record by hand: nothing would check the change.
