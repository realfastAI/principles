# Skills: a description that wins selection, a lean body behind it

Every listed skill's name and description cost context on every turn, and the
description alone decides whether the body loads. Ask: does the description say
what the skill does and the concrete situations that should load it, in the
third person? Should a person invoke it by name instead, keeping it out of the
listing? Is the body lean, with detail one link away? Does the body explain why
rather than shout? Is this a skill at all, or a hook or a rule?

## What loads, and what it costs
- Names and descriptions sit in a listing shared by every personal, project and plugin skill, within a character budget scaled to the context window. When it overflows, the least used descriptions are dropped first, and a skill shown with no description rarely fires. (Claude Code)
- Each description is cut at a per-skill cap in the listing. Put what and when first. (Claude Code)
- A skill marked for manual invocation only keeps its description out of the listing. Use it for anything a person starts by name. (Claude Code)
- Once loaded, the body stays in context across turns, and only its opening part is re-attached after compaction. Put the standing instructions at the top. (Claude Code)
- Measure the listing's size after adding a skill rather than trusting a count; the docs set no limit by number of skills.

## The description
- Name the situations that should load it, not only the capability. Include the entry modes the model will miss: a task handed over without any triggering verb, or an edit that starts in an adjacent file.
- Write in the third person. Mixed point of view hurts discovery.
- Skills tend to under-fire, so a little insistence belongs here, in the description. Keep the body calm.
- Trivial one-step requests may never load a skill. For file types the skill must always govern, add `paths:` globs, and check that the host version honours them. (Claude Code)
- Keep the frontmatter valid YAML; a folded block avoids escaping trouble with colons and quotes. Respect the length limits on name and description.

## The body
- Keep it under about 500 lines. Move depth into sibling files linked directly from the body, never a chain of links.
- Spend lines only on what the model cannot infer: the project's cadence, gates and prohibitions. Cut any line whose removal would cause no mistake.
- Use the imperative and give reasons. All-caps rules are a sign to explain instead.
- Name the skill for the activity it governs, lowercase with hyphens, a gerund preferred; never `helper`, `utils` or `tools`.

## Choosing the carrier
- Procedural knowledge applied while working: a skill. A side effect that must always fire: a hook, which does its own work and never starts a skill. A heavy isolated job: a subagent or a forked skill. A rule for every session: the instructions file. (Claude Code)
- Prove a change with a trigger test recorded before and after: it fires on the missed case and stays quiet on near misses.

Sources: [skills](https://code.claude.com/docs/en/skills),
[skill authoring](https://platform.claude.com/docs/en/agents-and-tools/agent-skills/best-practices).
