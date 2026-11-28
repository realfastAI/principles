Use it after request logging was turned on and the host relaunched with the launch line, to see what was
captured: whether requests arrive, from which sessions, and how much of the disk they take. A long session writes
its whole context with every request, so the folder can grow fast. A logged request holds the user's account email as well
as the working context, and the host writes its files readable by other local users, behind a folder
`turn-on-request-logging` makes readable only by its owner.

It writes nothing. It refuses with `request_logging_unguarded` while `.principles/request-logging/` exists
without its `.gitignore`, and with `request_logging_not_ignored` while git does not ignore every file there, before
reading a logged request.

`sessions` lists each session the host's `requests/index.jsonl` names, in the order it first names them, with its
`session_id`, its `requests`, the `files` its requests and their responses fill, and their `bytes`.
`orphan_requests` counts the request `files` no index line names, and their `bytes`; judge why from the session. An index line that is not a JSON object naming a session and its files is left out.

It never says whether the session you run in is capturing: the host's telemetry variables never reach your shell, so
judge that from the sessions and their sizes.

`newest` names, under `request_written_at`, when the newest request file was written, in UTC, and under
`session_id`, the session of the index's newest line; each is null before there is one. Compare the time with now to
judge whether requests still arrive.
