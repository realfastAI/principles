Use it when you are done capturing the requests the host sends, so later sessions stop filling
`.principles/request-logging/requests/` with copies of their whole context.

It empties the `env` of `.principles/request-logging/settings.json`, the launch file, and lists it under
`wrote`, so a host started with that file captures nothing. Where request logging was never turned on it writes nothing.
It deletes no logged request: those already captured stay in the folder, which git ignores. A host already running keeps
capturing until it is relaunched, which `next_action` says.

Before writing, it refuses with `request_logging_unguarded` while the folder exists without its `.gitignore`, and
with `request_logging_not_ignored` while git does not ignore every file there.
