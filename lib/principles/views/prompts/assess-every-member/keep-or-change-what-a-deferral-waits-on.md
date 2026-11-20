A deferral may carry `waits_on`, the one line an earlier audit gave saying whom it waits on and to decide what, and
`waits_on_since`, when that was asked. Check that the same person still owes the same decision: leave `waits_on` out
of a `still_holds` decision to keep it as asked then, give a new line when the ask changed, or null when it waits on
no one now. A null, or making the finding `accepted`, drops it, and the completed result names what it dropped.
