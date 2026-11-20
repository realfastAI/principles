![Six pocket compasses on white paper, every needle pointing the same way but one small red needle that has swung off course](https://raw.githubusercontent.com/realfastAI/principles/main/images/banner.webp)

# Harness Principles

<p>Built with ❤️ at&nbsp;<a href="https://realfast.ai"><picture><source media="(prefers-color-scheme: dark)" srcset="https://raw.githubusercontent.com/realfastAI/principles/main/images/realfast-logo-white.svg"><img src="https://raw.githubusercontent.com/realfastAI/principles/main/images/realfast-logo-ink.svg" alt="realfast" height="15"></picture></a></p>

[![Plugin](https://img.shields.io/badge/dynamic/json?url=https%3A%2F%2Fraw.githubusercontent.com%2FrealfastAI%2Fprinciples%2Fmain%2F.claude-plugin%2Fplugin.json&query=%24.version&label=plugin&prefix=v&color=e3120b)](#install) [![License](https://img.shields.io/github/license/realfastAI/principles)](LICENSE) ![Coverage](https://img.shields.io/endpoint?url=https://raw.githubusercontent.com/realfastAI/principles/main/badges/coverage.json) ![Specs](https://img.shields.io/endpoint?url=https://raw.githubusercontent.com/realfastAI/principles/main/badges/specs.json)

**Tighter harness, longer running agents: trust the principles, loosen the supervision.**

Built for Claude Code. Codex is partly supported already, with full support coming soon, and Pi after that. Your principles are portable across harnesses that share the same context management vectors: Codex has no monitors, but shares almost every other vector with Claude Code, including `AGENTS.md`, skills and hooks.

https://github.com/user-attachments/assets/8bd9d6cb-893e-4422-86f0-ecad91af5aa9

## Who is this for?

Principles is based on a dead simple idea - an easy to use CLI that helps an agent create and manage a map of all the snippets of text across the harness that work together to create its _operating principles_.

You'll get the most from it when:

- a team of people and their agents use the same harness and repo to do their work and need to establish shared SoPs.
- your agents _need_ to run for long stretches, and need their operating principles reinforced consistently across CLAUDE.md/AGENTS.md, skills, hooks and all the rest of the context management vectors a harness provides.

If your project has a single `CLAUDE.md` at its root, `principles` is overkill. You can read that one file and keep it consistent yourself. Come back when your rules start to spread.

Here is one of *realfast*'s projects, where an agent answers which principles are in place, how many places carry each, and which findings are still open:

![An agent in Claude Code answering "what principles are in place already?" with a table of six mapped principles, the number of files carrying each, and their open findings](https://raw.githubusercontent.com/realfastAI/principles/main/images/principles-in-use.webp)

## Install

In Claude Code, add this repository as a plugin marketplace, install the plugin, reload your plugins, and start:

```
/plugin marketplace add realfastAI/principles
/plugin install principles@realfastai
/reload-plugins
/principles:principles
```

`/principles:principles` starts your agent mapping your project's principles. From there it follows what each result tells it, so you never need to learn the commands. The plugin also adds hooks that report which mapped places changed as each session starts and after each commit, and a `setup-ruby` skill your agent follows, asking you first, when no Ruby 3.4 is found.

From a terminal, or for another harness, install the gem instead. In Claude Code, the `!` prefix runs a shell command in your session:

```
! gem install principles
```

Then ask your agent to map your project's principles. It runs `principles list-principles` and follows what each result tells it, so you never need to learn the commands. `principles` needs Ruby 3.4, and finds one installed by rbenv when the Ruby on your `PATH` is another version.

## The problem: harness drift

Your agent works the way its harness tells it to: `CLAUDE.md` files, rules, skills, subagents, hooks and the scripts they call. A team's operating principles, such as test first or never commit on a red build, each end up written in several of those files.

Then someone sharpens a rule in `CLAUDE.md` but not in the reviewer subagent. Every file still loads and nothing errors, but your agent now reads instructions that disagree. That is **drift**. Left to pile up, it becomes **debt**: the same rule at different strengths, stale exceptions, checks nobody remembers adding. No review catches it, because each edit looks fine on its own. The problem lives between the files.

## What `principles` does

- **Finds the principles you already have.** It surveys your guidance and shows which principles it carries, and where.
- **Maps each one.** A map names every place that carries a principle, and the part each place plays.
- **Catches drift.** `principles list-member-problems --short` names each mapped place that changed since its last audit, in a few lines made for a session-start hook.
- **Audits the places together.** Your agent judges whether they still agree. `principles` checks that every passage it cites exists, and records the result.
- **Makes debt deliberate.** Each finding is fixed, or recorded with whom it waits on.
- **Shows what to trim.** It points out rules stated twice, or loaded into every session when only some tasks need them.

`principles` never edits your harness and calls no model. Your agent reads and judges; `principles` keeps the books: what is mapped, what changed and which step comes next. Every result is JSON that names the next command. Maps and audits live in `.principles/`, committed beside your code, so your team shares them and their history.

## Why it matters

An agent working unsupervised is only as good as the guidance in its context, and nobody is watching when that guidance is wrong.

- **Context efficiency.** Every line the harness loads costs the agent attention, in every session it loads in. Mapping each principle shows where it is stated twice, stated stale, or loaded where it is never needed, so that text can be cut.
- **Context relevant to the task.** A principle can record when its work is in hand, such as only while specs are written. An audit then flags each place that loads into every session anyway.
- **No silent drift, no growing debt.** Each change to a mapped place is caught and checked against the others.

Together these lengthen the time, and widen the kinds of work, for which you can leave an agent running and still get great work.

## Example: one rename, three files

A project states its naming rule in three places:

```markdown
<!-- CLAUDE.md -->
Name every file and function for what it is. When a term changes, rename it everywhere in the same commit.
Settled terms live in `docs/glossary.md`.

<!-- docs/glossary.md -->
- **order**: a customer's request to buy, before payment.

<!-- .claude/agents/reviewer.md -->
Reject a term that is not in `docs/glossary.md`.
```

A teammate renames "order" to "basket" in the glossary alone. The one-line diff looks fine, but the reviewer will now reject every `order` left in the code. At the start of the next session, the agent runs:

```sh
principles list-member-problems --short
```

```text
express-intent	docs/glossary.md	e6aabd6	Rename order to basket	audit
```

`principles start-audit express-intent` hands the agent all three places together. It reports the contradiction, citing each passage, and either finishes the rename or records an open finding. The audit is a file you commit: `.principles/audits/express-intent.json`. A typo fix costs less: the agent acknowledges that one place, saying in a line why its meaning is unchanged.

## One principle, many places

Take express intent: every name says what the thing is and why it exists, and changes when understanding does. This means the agent renames things continuously, as the team's understanding changes, so that names stay current. In code it renames with a tool that changes every reference at once, such as `ast-grep` or an IDE's rename over MCP. A project's root and nested `CLAUDE.md` files, its glossary, design docs, a reviewer subagent and its README can all carry that one principle. Its map names them, so a change to one is checked against the rest.

## Commands

Your agent drives these; each result names the next.

```sh
principles list-principles          # where to start
principles list-candidate-files     # survey the guidance you already have
principles create-principle express-intent --description "Every name says what the thing is and why it exists"
principles add-member express-intent CLAUDE.md --section "Name things by intent" --role "States the rule"
principles start-audit express-intent
principles submit-answer REQUEST_ID --file answer.json
principles list-member-problems --short   # what changed since the last audit
principles list-open-findings             # findings still waiting
principles show-meta-principle-passage    # a passage for CLAUDE.md that keeps the agent checking
principles show-hook-setup                # hook entries that report changes as a session starts and after a commit
```

The hook entries run `principles report-at-session-start` and `principles report-after-commit`, which a hook runs, not the agent.

`principles --help` lists every command, and `principles COMMAND --help` shows its steps. Each project keeps one `.principles/` at its root; `--project PATH` picks one, so projects in a monorepo stay independent.

## Harnesses

**Claude Code** is the first target. **Codex** agents can use the same CLI from a shell, and share the same maps and audits. `show-hook-setup` prints Codex hook entries too, not yet tried in a real Codex session; native Codex skills are not built yet, and loading estimates describe Claude Code only.

## Where it comes from

The project grows out of two practices developed through use: **express intent**, keeping names and definitions current as understanding changes; and **collaboration through agents**, helping people align on shared work through the agents they each work with.

`principles` is built at [*realfast*](https://realfast.ai), where it has kept the harnesses of our own projects consistent for the past couple of months.

## Issues

Report a bug or ask for a feature at [github.com/realfastAI/principles/issues](https://github.com/realfastAI/principles/issues).

## Licence

Principles is licensed under the [Apache License 2.0](LICENSE). Its [NOTICE](NOTICE) credits Sidu Ponnappa and Ontic Pte. Ltd. (realfast.ai) as copyright holders, and Apache 2.0 asks that every copy keep it.
