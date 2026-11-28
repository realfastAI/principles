# Rule files: one topic, scoped to the files it governs

A rule without `paths:` loads in every session like the root instructions, so
ask first whether it can be scoped. Does the file hold one topic, named in full
by its filename? Do its globs, quoted and in the documented forms, match the
files where the behaviour happens, and does the frontmatter parse? Is anything
in it needed before the first matching file is read or after a compaction? Does
it copy a page it could point to instead?

## When a rule loads
- An unscoped rule loads at launch with the same weight as the project instructions and is re-read after compaction, so it spends the always-loaded budget. (Claude Code)
- A scoped rule loads when the agent opens, creates or changes a matching file, including a single-file read through the shell such as `cat`. It arrives as conversation, so compaction summarises it away until the next matching touch. (Claude Code)
- Listing a directory, grepping, globbing or writing a file through a shell heredoc are not documented triggers. Do not scope a rule whose duty starts there. (Claude Code)
- A rule that arrives with the first write of a new file cannot shape that write. Put guidance needed before the file exists in an unscoped line.
- Subagents pick up matching scoped rules the same way when they work with those files. (Claude Code)

## Frontmatter and globs
- `paths` is the only field read; any other is ignored without warning. (Claude Code)
- If the YAML fails to parse, the rule loads as if it had no `paths`, in every session. Check the header after each edit; the debug log shows the parse error. (Claude Code)
- Quote every glob. Prefer `dir/**/*` and `**/*.ext`. A mid-path `**` is not shown in the docs, so prove it fires before relying on it, for example through the instructions-loaded hook event.
- Project globs resolve from the directory holding `.claude`; user rules resolve from the session's working directory. (Claude Code)

## What to put in it
- One topic per file, with a filename that tells a reader its subject unopened.
- Standing checks for that topic, worded so they can be verified, each "never" with its scope and reason. A procedure belongs in a skill or a page.
- Where a page already owns the content, the rule only points: one sentence of rule, the moment to open it, and where it lives, as a link or in backticks. An `@` import pulls the whole page in, which undoes the point.
- Team conventions go in the project's rules. A personal rule must not restate or contradict one; neither overrides the other, so the agent may follow either. (Claude Code)
- A loaded rule over the per-file size limit is cut to its start. Keep each file well under it. (Claude Code)
- Record the reason for a rule's scope in the commit message, not in a comment in the file.
- Rules are guidance. A rule that must always hold needs a hook, a permission or a failing check.

Sources: [memory and rules](https://code.claude.com/docs/en/memory),
[context window](https://code.claude.com/docs/en/context-window),
[hooks](https://code.claude.com/docs/en/hooks).
