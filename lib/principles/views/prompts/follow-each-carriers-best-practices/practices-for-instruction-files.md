# Instruction files: few lines, each owned once and checkable

A root file loads in every session, a nested one only for work in its folder,
so each line costs every task in its scope. Ask: would the agent err without
the line, or could it read this from the repository when needed? Does another
file own this rule, so this copy will drift? Does the line name something
checkable, a command, path or value, and say why? Does it belong here, or in a
scoped rule, a skill or one directory's own file? Does any line describe
something that no longer exists?

## What loads, and what it costs
- The root file, the local file, the user file and every rule file without `paths:` load at launch in every session, and the root and unscoped rules are re-read after compaction. (Claude Code)
- A nested `CLAUDE.md` loads only once the agent reads or edits a file in its directory, so it is the cheap home for one directory's facts. (Claude Code)
- Codex joins the `AGENTS.md` files from the project root down to the working directory once at start, later files winning, and stops at a byte cap. A nested file is not deferred there. (Codex)
- An `@` import is expanded into context with its parent: it organises a file but saves nothing. Mention a path in backticks to point at it without loading it. (Claude Code)
- Anthropic's target is under 200 lines per file. Count words as well: a few long lines can hide a large cost.

## Route each line by how it is used
- A fact or standing rule for every session goes in the root file. A topic for one part of the tree goes in a path-scoped rule. Steps you run in order belong in a skill or in a page a rule names. One piece of work's facts go in its working folder.
- Leave out what the agent learns by reading the code and would look up anyway. Keep exact commands, places where the code misleads, decisions the repository does not record, and anything corrected twice.
- Treat a new line as a displacement: find its home before finding room, and cut a line that outlived its subject first.

## Wording
- Give each rule one owner and link to it from elsewhere. Copies drift, and the agent settles a contradiction arbitrarily. Check that every link resolves.
- Name the checkable thing and the reason: "run `rake lint` before committing; CI rejects unformatted files" lets the agent judge cases the line never names, where "keep code tidy" gives it nothing to act on.
- Write the plain imperative. Attach to each "never" the case it covers and why. Capitals and stacked emphasis make current models over-apply a rule.
- Give one canonical example, not a catalogue of variants.
- If a rule may not be skipped, enforce it with a hook, a permission denial or a failing check. These files are advisory context, not enforcement.

## Keep it true
- Reconcile the instructions in the same change that renames, moves or retires what they describe. A stale line misleads every session.
- Put why a rule exists in the commit message that adds it, not in a maintainer note in the file.
- Confirm what actually loaded rather than assuming: the context view lists the memory files. (Claude Code)

Sources: [memory](https://code.claude.com/docs/en/memory),
[best practices](https://code.claude.com/docs/en/best-practices),
[AGENTS.md in Codex](https://developers.openai.com/codex/guides/agents-md).
