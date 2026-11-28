# Hook scripts: quiet, fast, deterministic, and safe when they fail

What a hook script prints may land in the agent's context, on every event it
matches. Ask: does it print nothing when there is nothing to act on? Is each
line it prints short, specific and actionable? Does it give the same output for
the same state, with no network or slow work in the hot path? Does its exit
status mean what the host reads it as, and what happens when it crashes, times
out or a tool it calls is missing?

## What it prints
- Silence is the default. A line printed when nothing needs doing teaches the agent to skim every later line.
- Print the fact and the next action, in one or two lines: the file, the check that failed, the command to run. Not a banner, a preamble or a restatement of the instructions file.
- On session start, every byte is paid in every session and again after each compaction. Point to a command or file the agent can read when needed rather than inlining a page. (both)
- Plain text and JSON are read differently. Print exactly one JSON object, with nothing else on stdout, or plain text, never a mix. (Claude Code)
- Diagnostics go to stderr or a log. On exit 0 the agent never sees stderr. (Claude Code)
- Never print secrets: oversized output is written to disk. (both)

## Exit status
- Exit 0 for success, including when the script chose to say nothing.
- Exit 2, with the reason on stderr, to block an action that can be blocked. Exit 1 does not block. (Claude Code)
- On a Stop event, a block tells the agent to keep working, using the reason as its next prompt. Make that reason a concrete task. (both)

## Determinism and speed
- Same input and state, same output. A script that varies by clock, randomness or network is hard to trust and harder to test.
- Session-start and prompt hooks block the session until they finish. Keep the work small, cache what is costly, and push slow or optional work to a background run whose output does not gate anything. (both)
- Read the event's JSON from stdin rather than guessing from the environment. Do not depend on the transcript's format; it is not a stable interface. (Codex)

## Failing safe
- Decide per script which way failure should fall. A reminder fails open and silent. A safety block should fail closed, but only if the script cannot trap the agent.
- Guard against a missing interpreter, a missing tool or a path from the wrong directory: resolve paths from the project root, check dependencies, and say plainly what is wrong in one line.
- With blocking on failure set, a crash on a Stop or completion event keeps the agent looping on a hook it cannot repair. Test that path. (Claude Code)
- Test the script by running the real trigger and reading what reached the agent, not only by running it by hand.

Sources: [hooks reference](https://code.claude.com/docs/en/hooks),
[Codex hooks](https://developers.openai.com/codex/hooks).
