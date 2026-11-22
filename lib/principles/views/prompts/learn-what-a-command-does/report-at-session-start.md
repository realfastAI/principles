Run by a SessionStart hook, not by the agent: it prints what the agent should act on as a session starts, and the host
adds that to the agent's context. It reads the hook's JSON on stdin until stdin closes, or until a second passes with
nothing more, so a shell that leaves stdin open is not kept waiting; it reads nothing from a terminal. It always exits
0, since a host adds a SessionStart hook's output to the context only on 0, and shows the user an error on any other
status. In a project with no maps it prints nothing.

Otherwise each line it prints starts `principles:`. Input that is not JSON, or names no source a host sends, is read as
a startup. First, when one principle has a member an audit assessed that changed since, comes a line counting them,
saying its audit no longer covers them, and asking the agent to run, before the user's task, the `list-member-problems
ID` command that offers acknowledging them or auditing again; when several principles have, one line counting the
principles, with the `list-member-problems --short` command that lists them, so the line does not grow with their count.
An edit to a member no audit has assessed is not counted here, since it carries no verdict to act on. In git, a line
follows for each principle with members no baseline holds yet, as a session that ended mid-mapping leaves them, saying
which files to commit, or the audit to run when every file is committed already. Outside git only an audit gives a
baseline, so that line would repeat at every session, and is left out. Then a line for each principle whose audit record
a later release of principles wrote: this copy does not check its members, so none of them is counted, and the line says
how to update. Then, while any principle awaits its first full audit, one line counting them, naming none, asks the
agent to tell the user and start one background subagent to follow `show-first-audit-brief`, or to offer the audit at
its next pause if it cannot. At resume and compact, when one may be running already, it gives the count alone and asks
for no second one. Last, while any finding an audit deferred or accepted is open, the one line `list-open-findings
--short` prints, worded for the session's start, and short on resume, whose conversation holds the whole line already.

When the maps or members cannot be read, as `list-member-problems` would refuse, it prints instead the refusal's code
and that command, whose refusal says why and how to repair it, and still exits 0. Stdin that cannot be read is read as
empty input. Any other failure prints one `principles:` line naming it, and exits 0 too.
