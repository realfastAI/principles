Prints the answer to fill for the correction a full audit's assessment with findings opened, which
`submit-answer` names rather than prints. Print it again whenever you lose it; you need not submit the assessment
again. It reads principle ID's open audit record and writes nothing.

It prints the correction's answer alone: its `request_id` and `basis`, which you hand back unchanged, and one disposition for each finding to fill.
Redirect it to the file `submit-answer`'s `next_action` names by its full path, outside the project, fill only
its `dispositions`, and submit it with `submit-answer --file` and that path. It prints the same answer in git and outside it, and still
after you fix members, which leaves the correction current; `submit-answer` checks it as usual.

It refuses with `no_open_correction` while none is open to print. With no audit open, or only a completed
one, its repair names the full audit to start. With an audit open whose record an earlier release wrote,
which keeps no correction, it says to submit the assessment again, which prints its correction and keeps it.
