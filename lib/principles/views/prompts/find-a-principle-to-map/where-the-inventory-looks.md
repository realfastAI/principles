By convention, CLAUDE.md, AGENTS.md, .claude rules, skills, agents and settings, and Codex .agents/skills, .codex/hooks.json and .codex/agents, in this project. Also included are Markdown files changed by --commits-after,
changed mapped files, and files explicitly selected with --also or recorded guidance search paths. Files git
ignores are named under ignored and not listed to map. The host may still load an ignored file, such
as personal local settings, which can hold hooks and permissions, and whose hooks show-principle reads for
named_in_hooks; while it is ignored and uncommitted, an audit refuses a member in it, so a rule only it enforces
stays outside every audited map. Markdown and settings files are listed by name, except that a skill lists only its
SKILL.md, the file the harness loads, unless explicitly selected with --also, recorded search paths or the commit range. Any other file there, such as a skill's references, templates or scripts, is
counted under its directory in other_files_by_directory, so read one when it may hold a member. Explicit selections list other text files by path and size, without Markdown outlines. Members elsewhere in
the project are just as valid, and often the strongest: git hooks, CI workflows and executable scripts enforce a
principle, where instructions only state it. Look there too, and add any that reinforce the principle. Nothing is
executed; delivery is not observed.
