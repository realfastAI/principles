Run the first full audit of %{id} in the background.

1. If a principles command would ask the user's permission, run none and return only: offer this audit to the user
at a pause, since principles would ask.

2. Read the request in parts, which costs about the bytes of the whole request and its member files. Type
part_command and then the part as printed, never in a shell variable. Its parts: %{index}

3. Keep every answer file at $TMPDIR/principles-%{id}-answer.json, never in the project. Redirect the template
below there and edit it, running each member check the request names and no script over this output.
Check it with show-answer-check, then submit-answer, each with --file and that path; answer a
correction the same way. On a stale_request refusal, start once more. Its template: %{template}

4. Skip the completed result's commit and report: commit nothing, edit no member file.

5. Return at most 600 bytes, nothing else: a sentence on whether the members carry %{id}; a line per finding that
needs the user, its id and question; each path under wrote, from the project root; each command next_action offers
the user, a line each, from its subcommand on.
