Use it before you capture the requests the host sends, to see which mapped members' text reaches the agent's
context. The project's first full audit to complete names it in `submit-answer`'s `next_action`, for the agent
to offer the user, while no request is logged here. A request holds the session's whole working context, the files
read and every tool result, so it must never be committed: this command sets up a folder git ignores before anything
is written there.

It writes `.principles/request-logging/.gitignore`, holding `*`, unless it is there, so git ignores the folder and
all it holds, and lists it under `wrote`. Then it asks git whether it ignores the folder's files and every file
already in it. Outside git, or when git tracks a file there, it refuses with `request_logging_not_ignored` and
removes what it wrote; its repair says how to make git ignore the folder.

Once git confirms it, it writes `.principles/request-logging/settings.json`, the launch file, and lists it
under `wrote`. Its `env` turns Claude Code's telemetry on with its metrics, logs and traces exporters set to `none`,
and asks the host to write each request's body under the folder's `requests/`, by its absolute path. Claude Code
documents reading these variables at launch, from a file passed with `claude --settings`, and ignoring them in a
project's own settings. A real launch wrote the bodies with the exporters off, read from `--settings` as from
variables exported in the shell. A logged request holds the user's account email as well as the working context. The
host writes each file readable by other local users; this command makes the folder, when it is new, readable only by
its owner.

It prints `launch_line`, `claude --settings` and the launch file's path, for the user to start Claude Code with.
Capture starts only on that launch, so the host must be relaunched with it. It is a line, never an alias, since an
alias would capture in every project the user starts the host in; each checkout or worktree writes its own launch
file. `resume_line` is the same line with `--resume`, to keep the conversation. The line starts the host from a
shell; a host the Desktop app or an IDE starts is not given the file. `next_action` says what a logged request
holds, that the launch file overrides a telemetry exporter the user set up, for that launch, and that
`turn-off-request-logging` deletes no logged request. Git ignores the folder, but a backup or an archive of the
project still holds it.

`explain_to_user` is a paragraph for the agent to give the user before the relaunch: what a logged request holds and
who can read it, that subagents' and side calls' requests are logged too, its disk use, `remove-logged-requests` and
`turn-off-request-logging`, and that `--resume` keeps the conversation while any relaunch stops background agents.
