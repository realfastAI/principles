A check whose check_since_last_audit status is new or changed has not been run by an audit, and anyone who can
commit to the project can change it: before you run it, have it reviewed by the project's owner, or confirm it
against the project's own documentation, where documentation outside the check's own file counts for more than
comments in it, and otherwise report not_run_reason. Beside the exit status of a new or changed check, say in
review_basis, in one line, what that review rested on, such as who reviewed it or the document that confirms it; if
you did the review yourself, such as confirming against the documentation a check you changed, say so:
"Self-reviewed by the agent: <what you checked it against>"; if no record of it was kept, say that the basis was not
kept. This tool keeps the line and cannot verify it. You may give one beside not_run_reason or for an unchanged
check too.
