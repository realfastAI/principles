Run by a hook after each shell call, not by the agent: when the call committed, it names the mapped members those
commits changed, and the host puts that beside the call's result. It reads the hook's JSON on stdin until stdin closes,
or until a second passes with nothing more, so a shell that leaves stdin open is not kept waiting; it reads nothing
from a terminal. It always exits 0, since a host shows the user an error on any other status and gives the agent
nothing; a failure prints one `principles:` line naming it.

It looks at the call's own directory first, then each directory its command changed into with `cd` or ran `git -C` in,
and reports on the first mapped repository whose HEAD a commit moved during the call: its HEAD reflog was written
since the call started, and not by a checkout or a reset, which bring in no new commit. The output is the hook's JSON,
whose `hookSpecificOutput.additionalContext` names each changed member and the `list-member-problems` command that
shows it, or prints nothing when the commits changed no mapped member. A call that committed nothing costs a few git
calls and loads nothing else of this tool. A host that gives no call duration, as Codex does not, is read as a call
that took no time, so a commit made more than a few seconds before a long call ended is left to the next session
start.
