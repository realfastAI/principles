# Hook configuration: the right event and matcher, and output the agent needs

A hook entry decides when a command runs and whether its output reaches the
agent. Ask: does this event fire only when the work needs it, and is the matcher
as narrow as it can be? On a session-start or prompt event, is every byte it
prints worth paying for in every session? Is it a hook because the action must
always happen, not a preference? Does the command path resolve from any working
directory and worktree? Is it registered once?

## What reaches context, and when
- On session start and prompt submission, plain stdout and `additionalContext` are added as context the agent reads. Session start runs every session and after each compaction, so its output is an always-loaded carrier: keep it short, and put static text in the instructions file instead. (both)
- Output over the host's cap is saved to a file and the agent gets a preview. Do not rely on the agent reading the rest. (both)
- A pre-compaction hook's stdout instructs the summariser, not the agent; to brief the resumed agent, use session start with the `compact` source. (both)
- On other events, stdout on exit 0 is mostly not shown to the agent, and stderr on exit 0 never is. (Claude Code)
- Stop expects JSON on exit 0; plain text there is invalid. (Codex)

## Exit status and failure
- Exit 2 blocks on events that can block, with stderr as the reason. Exit 1 is a non-blocking error, not a block: a policy hook must exit 2. (Claude Code)
- On a pre-tool event, an error, timeout or malformed response can let the tool run. Treat tool hooks as a guardrail, not a complete boundary. (Codex)
- A failing hook fails open by default; opt into blocking on failure only where a missed check is worse than a stalled session. (Claude Code)
- A Stop hook that blocks keeps the agent working; a hook that cannot run there traps it. Make sure it can always start.

## Matchers and paths
- A matcher of plain names is exact; one with other characters is an unanchored regular expression, so `Edit.*` also matches other tools. Anchor with `^` and `$`. (Claude Code)
- Matchers are regular expressions, and some events ignore them. (Codex)
- Reference scripts from the project root variable. It stays at the main checkout when the session enters a worktree. (Claude Code)
- Commands run in the session's working directory, which may be a subdirectory; resolve scripts from the git root. (Codex)
- The same command registered in two files runs twice. Keep one format per layer. (Codex)

## Is a hook the right carrier
- A hook is right for what must happen every time: a block, a gate, a check. A preference belongs in instructions.
- Prompt and agent hooks ask another model, so they are not deterministic. (Claude Code)
- Codex parses prompt and agent handlers but skips them. (Codex)
- Project hooks must be reviewed and trusted before they run, and a changed hook is skipped until trusted again. (Codex)
- Hooks for an event run in parallel; one cannot stop another starting. (both)
- Never block compaction: blocked at the context limit, the request fails. (Claude Code)
- Command hooks time out after ten minutes by default, and prompt-submission hooks after 30 seconds. Set a short `timeout`: a slow hook stalls the session. (Claude Code)

Sources: [hooks reference](https://code.claude.com/docs/en/hooks),
[hooks guide](https://code.claude.com/docs/en/hooks-guide),
[Codex hooks](https://developers.openai.com/codex/hooks).
