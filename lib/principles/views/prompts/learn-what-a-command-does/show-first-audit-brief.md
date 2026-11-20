A principle's first full audit reads tens of kilobytes, which would crowd the context of a session busy with
its user's task. This command is for the background subagent that session starts to run that audit instead.
It writes nothing.

With no ID it lists, under `awaiting_first_audit`, the principles `list-member-problems` names as awaiting
a first full audit, and its `next_action` gives each one's brief command on a line of its own. Leave out any
your instructions or memory say to skip, and run one.

For principle ID it prints `principle`, `brief` and an empty `wrote`. The `brief` is what the subagent follows:
stop and say so if a principles command would ask the user's permission; read the request with
`start-audit ID --part index` and each part it names; fill the template `start-audit ID --as template` prints,
check it with `show-answer-check` and submit it with `submit-answer`; commit nothing and edit no member file,
in place of the completed result's commit step; and return at most about 600 bytes: a one-sentence conclusion,
each finding that needs the user, each path written, and the commands the completed result offers the user.
The session that started it commits the record by its path, or tells the user it is ready to commit.

It refuses with `first_audit_completed` once a full audit of principle ID has completed, since its later
audits start from `list-member-problems`; its repair names the command that lists the principles still
awaiting a first full audit.
