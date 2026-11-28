Shows each member of principle ID, where its text is now and whether it changed since the last audit. Audit when a
member is changed, unassessed, locator_lost or unavailable. A member that is locator_lost or unavailable carries
`repair_with`: a `move-member` with its `NEW_PATH`, `HEADING` or `QUERY` to fill in, for a section or passage a
second `move-member` for text moved into another file, and a `remove-member`. Run the one that fits;
`next_action` names those members. A member from an installed plugin carries `source`, with `read_only: true`;
one no installed plugin gives is `plugin_unresolved`, with its `reason` and no `repair_with`. `--member MEMBER_ID`
prints that member alone, its `last_assessment` and any `last_acknowledgement` since; an unknown id is `unknown_member`.

`--loads` adds each member's `loads` and the rest below. Each member's `loads` says, for each host this tool derives,
when that host loads the member's file into the agent's context. Only `claude_code` is derived; Codex is not yet.
It follows Claude Code's documented loading by path, for a session at the project root, not what loaded in one:

- `session_start`: the project's `CLAUDE.md`, `.claude/CLAUDE.md` or `CLAUDE.local.md`, in every session.
- `on_files` with `files`: one of those files in a folder below the root, once a file in that folder is read,
  written or edited.
- `session_start` too: a rule in `.claude/rules/`, or a folder within it, with no `paths` field in its frontmatter.
- `on_files` with `paths_field`: a rule with a `paths` field, once a file it matches is read, written or edited.
  `paths_field` is the field's lines as written; this tool does not read the globs, so read them yourself.
- `on_invocation`: a skill's `SKILL.md` in `.claude/skills/NAME/`, whose body loads when the skill is invoked.
  `invoked_by` is `model_or_person`, or `person` when its frontmatter says `disable-model-invocation: true`, so only
  a person's `/NAME` invokes it. This tool reads that field only as a plain `true` or `false` on its line.
  `description` says when the skill's description, which tells the model the skill exists, loads: `session_start`;
  `on_files` with `paths_field`, for a skill with a `paths` field; `on_files` with `files`, for a skill in a folder
  below the root; or `not_loaded`, for a skill only a person invokes. Other files in a skill's folder are
  `no_known_carrier`: the skill's body may tell the agent to read them. A member that is the skill's description
  field, by a query that names its `description` field such as `$.description`, has `skill_part: description` and
  the description's moment as its own `when`, with only its own `member_bytes`, since the file's size is the body's
  cost; any other frontmatter field's member gets the body's answer.
- `on_delegation` with `context: subagent`: a subagent's definition, a `.md` file at any depth in `.claude/agents/`.
  Its body is the subagent's own system prompt, loaded in the subagent's context, not the main session's, when
  Claude delegates to it; `description` is `session_start`, since Claude reads every subagent's description to
  decide when to delegate. An agents folder below the root, or an agent file without a `description` field, such as
  a note kept beside the agents, is `not_determined`.
- `not_determined`: This tool knows the file is a rule, a skill or an agent but not when it loads.
  `frontmatter_refused` names the code this tool refused its frontmatter with, so read the frontmatter; `not_derived`
  names a kind it does not derive yet, such as a rules folder below the project root or a plugin's file.
- `no_known_carrier`: This tool knows no Claude Code facility that loads this path by itself. An `@` import from
  another instruction file, or a user-level file, may still load it; read the importing file to check.

Whatever `when` says, `named_in_hooks` lists each project hook whose command names the member's file: its `settings`
file, `event`, `matcher` (left out when the event has none), and `command` and `args` as written. A command names
the file when it or one of its args gives the file's path from the project root, bare or after
`$CLAUDE_PROJECT_DIR`; a path reached another way, such as after a `cd`, is not recognised. This tool does not run
the command, so a name is not proof the hook runs the file, and it says nothing of whether the hook's output reaches
context: that depends on the event and on what the command prints, so read the event in Claude Code's hooks
documentation and the script. It reads only command handlers in `.claude/settings.json` and
`.claude/settings.local.json`; the local file is this checkout's own, and a handler in both runs once. It reads the
local file even where git ignores it, as Claude Code runs its hooks either way, so an owner's personal commands can
show here; list-candidate-files leaves an ignored file out of what it lists to map, not out of what loads. This tool
only prints them here and never writes them to a map or an audit record; if you quote one in an audit answer, that
answer is written to the audit record, which the project commits, so leave a personal command out of it. It does not
read user, managed, plugin or skill and agent frontmatter hooks, `prompt` or `agent` handlers, or `disableAllHooks`.
`hook_settings_not_read` names each of those two settings files this tool could not read, with its refusal code, so
an unreadable file is not taken for one without hooks.

`file_bytes` counts source bytes shared by every member in the file; `estimated_tokens` is source characters
divided by four, rounded up, not a tokenizer count. These are source measurements, not injected context sizes:
host processing and imports can change what reaches context. A skill's body waits for invocation; an agent's
body goes to its subagent. A `loads` without `context` refers to the main session.
`member_bytes` and `member_tokens` measure the member's own lines, equalling the file values for a whole-file member,
omitted when this tool cannot find the member. Before narrowing a section to save them, check whose lines they are:
`overlaps` names this principle's members sharing a line with it, `same_lines_as` those spanning exactly its lines,
and `mapped_elsewhere` other principles' members, each with its role, `first_line`, `last_line`, and `same_lines` when
spanning exactly the same lines, `spans_these_lines` when its lines include all of this member's, or
`within_these_lines` when they all lie within this member's. Each is left out when none shares a line.

Adding members' sizes counts a shared file once per member. `loading_basis` qualifies the aggregates below:
`host: claude_code`, `kind: documented_prediction`, `session_start_assumption: project_root`; not observed delivery
in Claude Code or Codex. Codex loading is not derived. The basis is omitted when no derived carriers are listed.
`files_loaded` lists each mapped carrier once, with `path`, timing and size from `loads.claude_code`, omitting
unknown carriers; hooks naming a file show on its members. `session_start_total` sums whole files at startup, when
they all load together; the files that load on files, on invocation or on delegation each load apart, so they are not
added up. Beside them, `descriptions` gives the `count` of skill and agent descriptions that load at session start
while their bodies wait, with their `description_bytes` and `description_tokens`: for a skill, its `description` and
`when_to_use` lines together, cut at 1,536 characters as Claude Code cuts each skill's listing
(code.claude.com/docs/en/skills, read 2026-11-09; a `skillListingMaxDescChars` setting changes that cap), and for an
agent its `description` lines. A skill only a person can invoke is left out, since its description does not load.
They are measured as written, each line with its key, quoting and trailing newline, so they are an estimate of what
the listing holds, and a skill's can exceed a description member's own `member_bytes` when it has `when_to_use`.
The total leaves out a file this tool cannot read, and whatever this principle does not map, such as user-level files,
imports and hook output: it estimates this mapped set's source size, not what a session starts with. The
files and descriptions it counts load at start whatever its activation, since the host loads them before an agent
reads the principle; the activation says when the agent works with the principle, and its other members load as their
own `when` says. Both are left out when there is nothing to list. Within the total, `files`, `file_bytes` and
`estimated_tokens` are left out when no file that loads whole at start could be measured, as `descriptions` is when
no description could; a file listed in `files_loaded` with no size loads at start uncounted.
