`loads_to_check_against_activation` lists each member whose loading you weigh against this principle's activation,
with the facts that put it there; this tool compares no globs. Decide each in `loading_decisions`; which reading fits
is your judgement. If the member rightly loads as it does, such as the principle's trigger, decide `accepted` with a
one-line `reason`; the record keeps it as accepting that loading. If the member is right but the activation is
wrong, do not accept it: change the activation and run start-audit again. Changing the activation makes this
request stale. If the member is in the wrong carrier and should load only with the work, that is a `finding`
decision, which is not built yet: raise it as a finding on the member instead, and accept the loading with a reason
naming that finding's id, so the record does not read as endorsing it.

A member whose loading the last full audit accepted carries `last_accepted`: its `reason`, and `since_accepted`,
`unchanged` or `changed`, comparing when the member loads and the member's own text, not its file's size, so a file
growing outside the member stays `unchanged`. An edit acknowledged with `--member`, or a fix made in that audit's
correction, counts as the text the decision was kept with. When `since_accepted` is `changed`, `last_accepted.changed`
names which moved, `loading` or `member_text`, beside the `loads` it accepted: weigh the decision again. When it is
`unchanged` and its reason still holds, decide `kept` with no `reason`; the record keeps the last accepted reason.

When this principle's work is in hand in every session, change the activation to always, under which no member is
listed here: %{always}
