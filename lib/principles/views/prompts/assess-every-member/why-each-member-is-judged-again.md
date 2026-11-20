Assess each member with `judge_because` afresh. In git, after a full audit, its `read_the_change` shows the edits to its
lines, or to a whole or moved file, since that audit's base commit; a change to its map entry, its loads or the
question does not show there, so an empty diff does not mean nothing changed. Its value says why this audit cannot carry
its last assessment:

`not_assessed_before`: no completed audit has assessed it.

`assessed_before_assessments_were_kept`: an earlier audit assessed it, but its record, written by a version of this
tool that kept no assessments, holds none to carry.

`description_or_question_changed`: the principle's description, or the question this request asks, changed since
the last full audit.

`changed_during_last_audit`: the last full audit's correction changed it, after it was assessed.

`text_changed`: its text changed since the last full audit.

`acknowledged_since_last_audit`: its text changed, and the edit was acknowledged with `--member`; judge the edits
together, as its `acknowledged_since_last_audit` says.

`moved`: its id changed since, as `moved_from` shows.

`role_or_check_changed`: its role or its check in the map changed since.

`loads_changed`: when it loads changed since.
