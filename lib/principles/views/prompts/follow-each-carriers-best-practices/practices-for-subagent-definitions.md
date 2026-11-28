# Subagent definitions: shared instructions only, for a worker spawned often

The description sits in the parent's context and steers delegation; the body is
the worker's whole system prompt. Ask: is this worker spawned repeatedly with
the same instructions, or is it a one-off prompt or a skill? Does the
description say what it does and who spawns it, without inviting unwanted
automatic use? Does the body hold only what every spawn shares, without
restating project instructions or a runbook's steps? Are tools, model and
isolation set deliberately?

## What loads where
- The body becomes the worker's system prompt, in place of the host's own. The worker also gets the spawn prompt and the project instructions, but not the parent's conversation, loaded skills or files read. (Claude Code)
- Some built-in workers, and a type set to omit them, start without the project instructions, so their spawn prompt must carry any rule the work depends on. (Claude Code)
- Each type's description is listed to the parent so it can delegate. Keep it short and specific; every word is paid in the parent session.
- An edited definition is picked up within seconds without a restart. If a new type is refused by name, spawn a general-purpose worker told to read the file first. (Claude Code)

## The description
- State the worker's job and the runbook or role that starts it. Leave out invitations to use it proactively when a runbook spawns it by name; keeping the description narrow is all that stops unwanted delegation. (Claude Code)
- Keep `name` unique: a project type outranks a user type of the same name. (Claude Code)

## The body and the spawn prompt
- The body carries the standing instructions every spawn shares: what to check, how to report back, where to stop.
- Where a runbook owns the procedure, name its section and tell the worker to run it. A copy of the steps drifts.
- Do not restate the project instructions or rule files; the worker loads them.
- The spawn prompt carries what differs per task: the objective, the output format, the tools and sources, and the boundaries. Thin briefs cause duplicated work and gaps.

## Frontmatter
- Spell each field exactly as the reference table does; an unknown field is ignored silently. A file without `name` is treated as documentation and never reported. Validate after editing. (Claude Code)
- Grant only the tools the job needs. A worker cannot ask the person a question; decisions that belong to a person come back to the parent. A background worker loses most built-in tools. (Claude Code)
- No field limits which paths a worker may write. A write fence is either a file list in the brief or a pre-tool hook. (Claude Code)
- A model passed at spawn beats the file's `model`. Set `model` in the definition where the job depends on it, and do not override it by habit. (Claude Code)
- A worktree-isolated worker starts from the default branch, not the parent's head, and an unchanged worktree is removed. Move it to the right branch first. (Claude Code)

Sources: [subagents](https://code.claude.com/docs/en/sub-agents),
[extension overview](https://code.claude.com/docs/en/features-overview).
