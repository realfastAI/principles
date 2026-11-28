Request logging keeps a copy of every request Claude Code sends to the model, under
`.principles/request-logging/requests/`, so `principles` can show which of your principles' text actually reached
the agent. Each logged request holds your account email and the session's whole working context: the conversation,
the files read and every tool result. Requests for subagents and the host's side calls are logged too. The host
writes each file readable by every user on this machine; this command makes the folder, when it is new, readable
only by you, which keeps them from other users while it stays so. Each request is a whole copy of the context, so a
long session's logs reach hundreds of megabytes: `remove-logged-requests` deletes all but the newest five sessions',
and `turn-off-request-logging` empties the launch file, so a launch with it logs nothing. Capture starts only once
Claude Code is relaunched with the printed `launch_line`, or with `resume_line`, which adds `--resume` to keep this
conversation; any relaunch stops the background agents running now, and for that launch, the file sets every
telemetry exporter you set up to none.
