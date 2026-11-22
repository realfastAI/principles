# Changelog

<!-- For agents: Follow [Keep a Changelog 1.1.0](https://keepachangelog.com/en/1.1.0/). As notable changes land, add entries under `Unreleased`, grouped as Added, Changed, Deprecated, Removed, Fixed or Security. Cite no task, decision or ticket numbers and link no ticket: the changelog is published, and they are not; commit subjects carry them. Curate changes rather than dumping commits.

Write each entry for the person deciding whether to upgrade: whoever runs agents with `principles` and pays for their context, time and supervision, or whoever publishes it. In one to three sentences:

1. Open with a bold lead naming the outcome that person gets, in their terms: less context or fewer tokens spent, fewer refused or repeated steps, a drift or mistake now caught, an agent that runs longer without someone stepping in, or a release that cannot go out broken.
2. Then say how they get it, naming the command or option they or their agent will use.
3. Give the measured effect as a plain comparison, such as "about a tenth of the bytes" or "one answer instead of one per principle", where the change or its commits measure it.

The agent's mechanics are the means, never the lead: do not open with "An agent no longer…". Leave refusal codes, field names and JSON shapes to the help text unless the reader must act on one; mark a breaking change "**Breaking:**", before or after the lead, and say what to change. Word a change with no user-visible effect for contributors. Claim only value the change or its commits show; never invent it. At release, use the actual version and `YYYY-MM-DD` date; never infer publication from a version bump. Preserve released history.
-->

## Unreleased

## [0.0.11] - 2026-11-22

### Changed

- **An audit reads the parts of a request it needs in one call, with no script to stitch them together.** `principles start-audit ID --part A --part B` prints each part named, in the order given, under the request's one `request_id`, instead of one call per part, and beside `--as template` each member's slot named in one `member_assessments`. `--part response_template`, the bare answer to save as it stands, is refused beside another part.
- **Checking a principle's changed members reads only what decides the next step, with no script to pull the fields out.** `principles list-member-problems [ID]` now gives each changed member's id, state, baseline and the command that clears it without the list of commits that changed it, one entry per commit; `--history` adds that list back when your agent needs it.
- **A session start costs the same whether one principle's audited rules changed or several did.** When more than one principle has changed audited members, `principles report-at-session-start` prints one line counting them, with `principles list-member-problems --short` to list them, instead of a line per principle: 208 bytes for any number of principles, where four printed 747. A single principle's line is as before.
- **A member named by its heading or passage alone is one command away from the right id, not a trip through `show-principle`.** When `change-member-role`, `change-member-check`, `remove-member-check`, `move-member` or `remove-member` is given text that exactly one mapped member's id ends with, after its `#` or `@`, the refusal names that id and starts its repair with the same command run on it. Nothing runs on the guess itself.
- **Your agent fills a full audit's answer with its own file editor, with no script to unwrap or escape it.** `principles start-audit ID --part response_template` now prints the answer bare, ready to save and submit as it stands, and the request and its `--part index` say to save it to a file outside the project, fill it there with the agent's file-edit tool rather than a shell heredoc, and submit that file, naming the only three characters JSON escapes. The line adds about 420 bytes to each full-audit request. A correction's next step says the same of its dispositions, saved from `show-open-correction`, and an acknowledgement request, for one member, several or members across principles, now has a next step too, saving the answer `--as template` prints, and its refusals send the agent back to that saved answer rather than to the request.
- **Each member's slot in a full audit's answer is its own, so a file editor's one-match replace fills one slot at a time.** Every judged member's assessment placeholder now names its member, and an answer that leaves any member's placeholder in a slot, its own or one pasted from another, is refused as left as printed. A correction's dispositions do the same, each one's action, reason and reassessment placeholders naming its finding, and so does each member's entry in an acknowledgement's answer.

## [0.0.10] - 2026-11-21

### Changed

- **Your agent raises open audit findings that wait on you in its first reply, instead of skimming past them.** The open-findings line `principles report-at-session-start` prints now names the oldest finding waiting on someone and what it needs, states git's `user.name` for the agent to judge whether that is you, and says to raise each in the first reply, since nothing else will. On this tool's own repository the line is 30% shorter than before.
- **You see how long the oldest finding has waited on you, so a stale one stands out.** The open-findings line `principles report-at-session-start` prints says "open N days" beside the oldest finding it names, as it did before the line was rewritten, for 15 more bytes.
- **Your agent deals with changed audited rules before starting your task, instead of leaving the notice for later.** Each line `principles report-at-session-start` prints for a principle whose audited members changed now says that its audit no longer covers them, and asks the agent to run `principles list-member-problems ID` before your task, to acknowledge the edit or audit again. The closing line that pointed at those commands is gone.
- **The README opens with a 51-second video of what principles does.**
- **The tagline now reads "Tighter harness, longer running agents: trust the principles, loosen the supervision."** in the README and the gem summary, and the gem description says what the README says of harness support: built for Claude Code, Codex partly supported, Pi after that.

### Removed

- **Each session starts 110 bytes lighter.** `principles report-at-session-start` no longer restates the meta-principle line; it prints only lines naming a fact and a command.

## [0.0.9] - 2026-11-21

### Added

- **One command answers "what principles are in place, and what is each still waiting on?"** Run `principles list-principles --open-findings`: each principle's row adds its open findings, one line each, saying whom it waits on and how long it has been open, so an agent no longer joins `list-principles` with `list-open-findings` in a script. Without the flag, `list-principles` prints as before, about a fifth smaller than with it.

- **Install `principles` in Claude Code from its public repository.** Run `/plugin marketplace add realfastAI/principles`, then `/plugin install principles@realfastai`. The plugin's hooks report which mapped places changed as each session starts and after each commit, and its `setup-ruby` skill installs Ruby 3.4, asking you first, when none is found. The gem stays the install for a terminal or another harness.

### Changed

- **The public repository's README now shows its images.** For publishers, every file under `images/` is published byte for byte at the same path in the public repository, and never added to the gem, so both READMEs share one copy. The leak check still reads an SVG as text, and leaves a binary raster image unread, since its compressed bytes can spell a refused word by chance.

- **A release can no longer stop half-done on an unclean public checkout.** For publishers, `bundle exec rake release`, the dry run included, now refuses before the gate and before tagging when the public repository's checkout has uncommitted or untracked files. It names each file and says to commit or remove them there.

- **The gem you install is built from the public repository's commit, so it matches the source you can read there.** Each release commits its public copy first, builds the gem from that commit, dated by it so a rebuild is byte-identical, and only then pushes; for publishers, `bundle exec rake release` checks before any step that the gem builds and installs from that copy, and a stopped release finishes by running it again, uploading nothing RubyGems already serves.

- **Licence scanners now recognise `LICENSE` as the Apache License 2.0.** It is the text exactly as Apache publishes it; the copyright line stays in `NOTICE`.

## [0.0.8] - 2026-11-20

### Added

- **A principle you mapped but never audited gets its first audit without crowding your session's context.** While any principle has no full audit, `principles report-at-session-start` adds one line, under 300 characters, that counts them and asks your agent to tell you and start one background subagent to follow `principles show-first-audit-brief`. The subagent picks a principle from that list and follows its brief, about 1.5 KB: it keeps its answers in one file under `$TMPDIR`, never in your project, commits nothing, edits no guidance, and returns at most 600 bytes for the session to relay at its next pause, a line for each finding that needs you and the offered commands without their long paths, where an audit read inline costs the session tens of kilobytes. If a subagent cannot be started, or `principles` would ask your permission, the agent offers the audit to you instead. After a resume or compaction the line gives only the count, so a second subagent is not started, and once every principle is audited it prints nothing. Whether a session starts the subagent unasked is not yet tried in a real session.

- **Your company can adopt `principles` without a legal review.** The gem is now licensed under the Apache License 2.0, where it had no licence and so granted no right to use it; it ships `LICENSE` and a `NOTICE` crediting Sidu Ponnappa and Ontic Pte. Ltd. (realfast.ai) as copyright holders, which every copy keeps.

- **A gem install without the plugin now catches drift between audits too.** `principles show-hook-setup` prints the hook entries, for Claude Code's `.claude/settings.local.json` and for Codex's `.codex/hooks.json`, that run `principles report-at-session-start` as each session starts and `principles report-after-commit` after each shell call, so the agent hears which mapped places changed as the plugin's hooks tell it. Your agent writes them once you agree, and a completed first audit offers the command. The Codex entries are not yet tried in a real Codex session. When the `principles` on PATH is not the one you ran, it says so before the entries, naming any other version first there and whether that copy runs both report commands, asked of it directly, so you never paste entries that would print a failure line in every session. To remove them, delete the entries whose command starts `principles report-`. Each host's block says why it is offered, Codex's because `.codex/` exists when the project has one.

- **An audit reads a short member's change without the rest of its file's edits.** For a section or passage judged again, `start-audit`'s `read_the_change` now names `git log -L` over the member's own lines since the last full audit, in place of the whole file's diff, and so does a one-member audit's, `start-audit ID --member M`, since the member's baseline; a whole-file member, or one whose file moved, keeps the diff. On this repository's root `CLAUDE.md`, two one-line members' commands print about 3.6 KB and 1.4 KB where the diff printed 33 KB.

- **Your agent can audit a large principle in small reads, with no script and no member file opened, at a fraction of the context.** Every full-audit request from `start-audit ID` opens with `read_in_parts`, naming `start-audit ID --part index`. The index lists every part with the bytes it prints, each instruction and the answer to fill among them, printed as the whole request prints them, says which members this audit judges and which it carries forward, and ends with `answer_with`, the command that submits the answer, and a next step asking for every part but a carried member's, which your agent may skip unless it chooses to judge that member again. `--part NAME` prints one part alone, such as `prior_findings`, `members/ID` with that member's text, or `response_template`; `--instruction FIELD` prints an instruction whole; and `start-audit ID --as template --part members/ID` prints one member's slot of the answer. All the next step asks for costs no more than the whole request: about 11.4 KB against 11.8 KB on a five-member audit carrying every member with three prior findings. On this repository's sticking-to-your-principles audit the index is about 3 KB where the whole request is 39 KB; on its largest principle a typical member's part is about 4 KB and its slot under 1 KB.

- **Your first map no longer misses a project's Codex guidance.** `principles list-candidate-files` now lists Codex's skills in `.agents/skills`, its hooks file `.codex/hooks.json` and its custom agents in `.codex/agents`, beside the Claude Code files, and names each one git does not track, so your agent asks you about it before mapping. A skill whose entry file is spelt `skill.md`, or in any other case, is listed too, with its spelling stated, since a case-sensitive host may not load it. A project without them gets a slightly shorter survey: 30 bytes fewer on this repository.

- **Correcting a full audit costs fewer tokens and no hand-copying.** `show-answer-check REQUEST_ID --file FILE --as template` prints the correction's answer alone, ready to redirect to a file and fill, as `start-audit --as template` does for the assessment; plain `show-answer-check` no longer prints a copy of the answer that `submit-answer` printed again, 1,299 B less in one session's result.

- **A change to a member several principles map is acknowledged once, not once per principle.** `start-audit A B --member M` asks for one answer, judged once for every principle, and `submit-answer --file FILE` moves the member's baseline in each principle's record; `list-member-problems --short` now offers that one command where it printed one per principle. A member the principles check with different commands is refused, naming each principle's own command.

- **Changing a rule the project holds no longer misses a place that carries it.** Asked through `/principles` to change such a rule, such as a template its CLAUDE.md sets, the skill finds the principle with `principles show-principle ID`, edits every member, and repeats `principles list-member-problems --short` until it exits 0, where the agent had to find that route itself.

- **Correcting a full audit no longer drives your agent to a script, and a lost correction no longer means submitting the assessment again.** `principles show-open-correction ID` prints the open correction's answer alone, from the open audit record, in git or outside it and after fixes too; the correction's `next_action` names it, so your agent saves it to a file, edits only the dispositions by hand and submits that file. The correction's recovery note now names that command, where it named a replay of the assessment file that worked only in git and only before a fix, and is about a third shorter. A teammate's older copy refuses to rewrite such an open record, naming the release to update to, rather than drop its correction.

### Changed

- **Reading a full audit in parts no longer means quoting part names by hand.** `principles start-audit ID --part index` now prints the command that prints a part once, and each part's name quoted where a shell would split it, as a heading with a space, `#` or an apostrophe needs, so the name runs as printed after that command.

- **A full audit read in parts is answered without guesswork.** `principles start-audit ID --part index` now says, where it hands over the answer to fill, to keep each carried-forward member's entry as printed, filling only any check it asks for. An instruction printed in part now says it is enough for the request's own cases, so an agent need not fetch each whole, which cost one session about 7.7 KB more. It also says that `--as template` prints the same answer at length, with each slot's help, about four times the bytes of `--part response_template`.

- **An audit that raises no findings is no longer refused for leaving them out.** `principles submit-answer` now reads an assessment with no `findings` as one raising none, as it reads `"findings": []`, so an agent that drops the empty list need not answer twice.

- **Acknowledging a changed member takes one command fewer.** `principles list-member-problems --short` now says that the `start-audit ID --member M` it prints is the acknowledgement, for 32 more bytes.

- **Fewer refused steps when reading an audit in parts: a part this audit leaves out reads as empty, not as a wrong name.** `principles start-audit ID --part PART` now answers an optional part, such as `open_findings_elsewhere` or `prior_findings`, that has nothing to list for this request with `part_empty`, 83 bytes, where it refused the name as unknown.

- **Fewer findings wrongly changed or withdrawn: an accepted finding now reads as accepted.** `principles list-open-findings --lines` now prints `accepted` for an accepted finding, where it printed `waits on no one named`, which led one agent to change one finding and withdraw another. The session-start line no longer counts accepted findings among those with no `waits_on`.

- **An audit that raises findings costs less context at its correction step.** `principles submit-answer` no longer prints the correction's answer to fill, which its next step already prints alone with `principles show-open-correction ID` for you to save and fill. For one finding, that is about 1.2 KB less of the 9 KB it printed, and more for each further finding. When a correction answer is refused, the repair points to that command too, not to a template the request no longer prints.

- **A deferred finding left with no write-up is no longer mistaken for a refused one.** `principles show-answer-check` now names each deferral whose `recorded_at` is null, says that null is allowed when there is nowhere to point, and says that `list-open-findings` will then show no write-up for it. The answer guide's deferred example now says null is allowed too.

- **The plugin's Ruby setup no longer costs context in every session.** The `setup-ruby` skill, needed once and only when no supported Ruby runs `principles`, no longer loads its description into each session, about 230 bytes. When no Ruby is found, the session-start message and the `unsupported_ruby` refusal now give your agent the skill's file to read and follow, and it still asks you before installing anything. You can still run `/principles:setup-ruby` yourself.

- **Every session start, clear and compaction now costs about a third less context for open findings.** While audit findings are open, the line `principles report-at-session-start` prints says what to do in fewer words. It keeps whom to raise, not raising one again, and the command that lists whom each waits on. On this repository's 15 open findings, its instructions fell from 382 to 256 bytes at startup and from 385 to 246 after a compaction.

- **Every result costs your agent about a fifth fewer bytes of context.** Each JSON result `principles` prints is now unindented, one field a line, with no space after the colon, so `grep '"status":"question"'` matches every output, refusals included, and `grep`, `sed -n` and diffs read it a line at a time as before. A one-member acknowledgement fell from 6,067 to 4,886 bytes; `list-candidate-files` keeps each file's entry compact on one line.

- **A one-member audit refused during an open full audit now names that audit, not a missing one.** `start-audit ID --member M`, run while a full audit of ID waits on its correction, said the principle had no completed audit; it now says a full audit is open, waiting on its correction, and to submit that correction, with the command that starts the full audit again instead.

- **An acknowledgement across principles costs less context when they map the same member.** `start-audit A B --member M` now prints a shared member's lines once, under the first principle, and the other principle's entry names that principle under `change_shown_under` in their place; when the two judge the member from different text, each still prints its own. On this repository's two layer principles the request fell from about 7.9 KB to about 6.1 KB.

- **An acknowledgement across principles tells your agent which findings it leaves for a full audit.** When `start-audit A B --member M` keeps a deferred finding on a member it acknowledges, its request now names `list-open-findings --lines`, which prints those findings, and each such principle's full audit, the only step that resolves them. Before, the agent had to learn this from `start-audit --help` and read the audit records by script. The request grows by about 290 bytes for one principle, and about 110 more for each further one, run as `principles` with a short project path; a request that keeps no deferred finding is unchanged.

- **Before a full audit writes its record, your agent is told when a carried assessment cites a finding the same audit decided.** `show-answer-check` now lists, under `carried_assessments_citing_decided_findings`, each member whose carried-forward assessment names a finding the answer resolves, withdraws or raises again, and asks the agent to judge it afresh if it no longer holds, before the record is written; `submit-answer` names the same members, and the next full audit to run, for an agent that submitted without checking. Nothing is refused, since a finding id such as F1 can name another record's finding; it used to take a second audit to replace such text.

- **A full audit's answer template is smaller where most members are judged afresh.** `start-audit ID --as template` no longer prints `observation` and `observed_at` in every member's slot, which only a sighting fills; its `left_as_printed_rule` says once that a sighting sets `delivery` to `observed` and adds them. On this repository's largest principle the template fell from about 9.8 KB to 7.6 KB.

- **A full audit of a member edited in two distant places no longer prints the whole file between the edits.** `start-audit`, and `start-audit --member`, now print each edit with a few lines of context, under `changed_regions` when there is more than one, each later one counting the unchanged lines it skipped; a member edited in one place prints `changed_region` as before. On this repository's largest principle, one whole-file member's lines fell from about 9 KB to 1.5 KB, and the whole request from 74 KB to 66 KB. **Breaking:** a script reading only `changed_region` misses a member edited in two places; read `changed_regions` too.

- **Every command a gem install prints is short enough to read and survives a Ruby upgrade.** When the `principles` your agent runs is the gem's own on PATH, each printed command, repair and help page names the bare `principles`, and drops `--project` when run from the project's root, where it named a Ruby and the gem's path, about 100 characters tied to one Ruby release, then the project's absolute path. A run that a bare `principles` would not reach, such as another copy first on PATH, keeps the absolute form.

- **A gem install without the plugin no longer sends your agent to a skill it does not have.** `principles report-at-session-start` ends its changed-member counts by saying to run the commands they print, and `principles report-after-commit` ends at the command it prints, where both named the `/principles` skill, which only the plugin installs; under the plugin they still name it. The session's first line now says whose reminder it is, `Meta-principle: what loads at start costs every session's context; load only what the task needs.`, two bytes shorter than the unattributed line it replaces.

- **A broken or missing `principles` no longer shows you a hook error on every session start and shell call.** Both report commands always exit 0, and every printed hook entry falls back to one line saying `principles` failed to start. The plugin's hooks now run the same commands instead of shell scripts.

- **Filling a full audit's template takes less writing and fewer overwritten instructions.** `start-audit --as template` prints an unchanged check's `check_result` already filled, so only `exit_status` is left to fill; one template in this repository shrank from 7,833 B to 7,663 B.

- **One script can fill an acknowledgement whether it covers one member or several.** A one-member acknowledgement's template and answer now hold `meaning_kept`, `reason` and the rest under `members`, keyed by the member id, as several members' do. **Breaking:** an answer with those fields at the top level, as 0.0.7 printed it, is refused, naming each field and saying it belongs under `members`.

- **A full audit prints its run-and-report instructions once, not once per checked member.** The request and `start-audit --as template` print them once per standing (unchanged, changed or new) with the members they are for, and each member's own entry keeps only its own lines. On this repository's two principles with three and four checks, each print is 425 B and 664 B smaller.

- **Finishing a full audit no longer prints the same command twice.** `next_action` names `commit_with`, the command that commits only the audit's files, where it printed the same command again: 400 B less in the scripted session's result, about 1 KB at a real project's paths.

- **Commands copied from `list-member-problems --short --project ROOT` into a shell elsewhere run on the right project.** Each command it prints now names `--project`, and stderr no longer names the project a fourth time on its own line, keeping only `Details: drop --short.`; without `--project` its output is as before. Nine changed members across three principles print 1,150 B at a 32-byte project path with it, 997 B without.

- **Acknowledging a change no longer leaves the agent waiting for a commit before the members stop being listed.** The acknowledgement's `next_action` now says `list-member-problems --short` no longer lists them, as is true once the record is written, and the commit keeps that record for every other checkout.

- **You can see how long each open finding has waited without reading the full JSON.** `list-open-findings --lines` ends each finding's line with `open N days`, the whole days since it was first raised, as `--short` counts the oldest's; eight findings waiting on the user print 824 B.

- **One script can read the members an acknowledgement names, whether it names one or several.** A one-member acknowledgement's template `basis` and its `submit-answer` result now name the member under `member_ids`, a list of one, as several members' do, where they printed `member_id`. **Breaking:** an answer whose `basis` gives `member_id`, as 0.0.8 printed it, is refused at `/basis/member_id`, saying it is now `basis.member_ids`.

### Fixed

- **`principles report-at-session-start` and `principles report-after-commit` no longer hang when your agent runs them by hand.** Run from a shell that leaves stdin open and sends nothing, each waited as long as the shell allowed, two minutes in one session; each now reads stdin until it closes or a second passes with nothing more, so it adds at most a second to a run. A hook, whose host writes its input and closes stdin, reads it as before.

- **The meta-principle's audit no longer tells your agent its map holds none of the hook, the skill and the passage when it holds some.** `start-audit sticking-to-your-principles` now names, in `package_since_last_audit`'s why, which of the three the map holds: the passage by the heading setup maps it under, the hook as a mapped `.claude/settings.json`, `.claude/settings.local.json` or `.codex/hooks.json` whose hook runs `principles report-at-session-start`, as `show-hook-setup` prints it for a project without the plugin, whether mapped whole or as a passage whose own text runs it, or at the plugin source's own path, and the skill only at the plugin source's own path, since only the plugin installs it. So an agent judging an upgrade no longer raises a finding about a part it has already mapped.

- **On macOS, renaming a mapped file only in case is now caught as drift.** macOS's default disk still opens `Foo.md` under its old name after git renames it to `foo.md`, so `principles list-member-problems` used to report nothing while a clone on a case-sensitive disk could not find the member. It now lists each such member as broken, names the spelling git tracks, and offers a `move-member` to that spelling, ready to run once the agent checks it is the member's file.

- **A full audit no longer loses a kept finding's write-up pointer to a misread template slot.** In `start-audit ID --as template`, a prior finding's `recorded_at` slot read "a write-up pointer or null", and an agent took null for "no new pointer", dropping the one the finding had; it now says null drops it, and left as printed keeps it. `show-answer-check` on the assessment now names each finding whose pointer the answer drops, with the pointer, so your agent confirms the drop before the record is written, where it used to show only once the audit completed.

- **A full audit's correction can be recovered from the retained assessment, with no hand-copied basis.** `show-answer-check ID --file ASSESSMENT --as template` now prints the same correction `submit-answer` printed, and it submits, where a member check answered with a new review line printed another request id and basis that was refused, first as stale and then as edited. Once members are fixed, the stale refusal of that assessment names the members that changed, where it listed every possible cause. Its repair says to answer the open correction, which stays current, where it said to start the audit again.

- **Acknowledging several principles' members in one answer is no longer wrongly refused.** It was refused with `cannot_acknowledge` when a member's check is `list-member-problems --short` and lists another principle's member the same answer acknowledges, because each principle compared the listing with its own members alone; such an answer is now accepted.

- **Acknowledging a member several principles map no longer fails on a `check_result` its template never printed.** `start-audit A B --member M --as template` printed only the first principle's fields, so when only a later principle checked the member its `check_result` was missing; it now prints every field any of them asks for. An acknowledgement that leaves `check_result` out, gives the wrong `command` or gives no `exit_status` is refused with a repair naming the request's own guidance, where one named a full audit's `answer_guide` that no acknowledgement prints.

## [0.0.7] - 2026-11-19

### Added

- **An agent that types `principles help COMMAND` gets the page it wanted instead of an unknown-command refusal.** It prints the page `principles COMMAND --help` prints, and `principles help` the overview.

- **An agent raising the findings waiting on its user at session start reads a line per finding instead of the full list.** `list-open-findings --lines` prints each open finding's principle, id and whom it waits on, where the full list ran 24 KB for 17 findings in this repository; it is refused with `--short`.

- **An agent adding to CLAUDE.md, a rule, a skill's description or a hook's output is reminded, for 112 B, that every such line costs every session's context.** The plugin's session-start hook, in a mapped project, opens with `principles: Every line loaded at session start costs every session's context, so load only what the task needs.`, at startup, clear and compact but not on resume, whose conversation holds it already. `list-member-problems --short --session-start SOURCE` prints it, and the skill line after the per-principle counts, so the hook only relays them.
- **A full audit is no longer refused for an agent clock's own UTC offset.** `observed_at` may carry any offset, such as `2026-11-01T15:00:00+05:30`, and the record keeps the same instant in UTC, `2026-11-01T09:30:00Z`.
- **A full audit no longer asks for the same loading reason again, each audit, for a member whose loading is unchanged.** `loading_decisions` accept `kept`, with no reason, for such a member and the record keeps the last accepted reason; `kept` on a changed row, or one no audit accepted, is refused.
- **Editing a member whose check is `principles list-member-problems --short` no longer needs a full audit.** That check exits 3 while it lists the member, so it could not be acknowledged; now report the 3 and the member ids it lists under `check_result.listed_members`, as the request's `check_instruction` asks. It is accepted when that is what the check lists now and the answer acknowledges every one, so the check is clean once the record is committed; a different list, or a listed member the answer leaves out, is refused.
- **Acknowledging such a member no longer means adding `listed_members` to the template by hand.** `start-audit --as template` prints an empty `check_result.listed_members` slot for it, in a one-member template and in its entry of a template to several, to fill where it is printed; sent back empty beside an exit 3, it is refused.
- **A change that touched several members of one principle takes one answer, not a request per member or a script over their templates.** Give `start-audit ID --member A --member B`, fill each member's entry under the template's `members`, and submit it with `submit-answer --file FILE`: every member's baseline moves in one record write, or the answer is refused whole and none moves. A member given twice is refused.
- **Submitting a filled `--as template` no longer needs its request id typed on the command line.** `submit-answer --file FILE` alone submits it, since `submit-answer` and `show-answer-check` take REQUEST_ID from the answer's own `request_id` when you give none; a REQUEST_ID you give must still match the answer's, and an answer naming none, with none given, is refused.
- **A full audit's template no longer lets an agent miss a check the audit still asks it to run.** `start-audit --as template` names each member whose carried-forward marker the agent might skip at its head, under `carried_checks_to_run`.

- **A release `gem:publish` left `UNCONFIRMED` no longer has to be checked and advanced by hand, as 0.0.5 and 0.0.6 were.** `UNCONFIRMED` now names `bundle exec rake "gem:confirm[RECEIPT]"`, which never uploads and, when the exact versioned download matches the receipt's SHA256, prints `PUBLISHED`, records the receipt and prepares the next local patch.

- **The person publishing can make installing `principles` install the marketplace plugins it depends on, and cannot publish one whose dependency its marketplace lacks, which Claude Code would silently not load.** The plugin publish reads their names from `PRINCIPLES_PLUGIN_DEPENDENCIES` and the build writes them into the manifest's `dependencies`, and the publish refuses a dependency the marketplace does not list. 0.0.7 itself declares none: a practices dependency waits for a later release.

- **A contributor is told by the gate when a ticket README lacks its opening sections.** `bundle exec rake ci` fails when one does not open with Objective, Business value and Done when, each with text, and names what is wrong in each.

### Changed

- **An agent that guesses an option, such as `add-member --heading`, is shown the right one, `--section`, in the refusal itself.** A refused command line's `repair` names its command's usage, such as `Usage: add-member ID PATH [--section HEADING] ...`, before `To see what each takes: principles add-member --help`, where it said only to see `--help`; a missing argument is repaired the same way, as `submit-answer` with no `--file` is, where its repair named every command.

- **An agent at session start is sent to the findings to raise a line each, not to the full list whose JSON it then scripted over.** The session-start line about open findings ends `Whom each waits on: principles list-open-findings --lines`, 657 B in this repository, where it printed 660 B.

- **Each session that starts after members changed spends less context on telling the agent so.** The plugin's session-start hook prints one line per principle whose audited members changed, such as `principles: 3 audited members of clear-intent changed: principles list-member-problems clear-intent --short`, where it printed a row per member, capped at twenty: nine changed members of three principles print 439 B where they printed 730 B. It gets the lines from `list-member-problems --short --session-start SOURCE`, which prints them in place of `--short`'s rows and counts, keeping its stderr and exit status.
- **`list-member-problems --short` names the project once, not on every command, and prints about a third of the bytes.** It names it once on stderr, before its first command, as `In PROJECT (details: drop --short):`, and its commands leave out `--project`, so run them there; the separate `Details:` line is gone, and the acknowledgement lead is shorter. Nine changed members across three principles print 997 B across both streams, where they printed 2,913 B at 463cdb7e, measured in a controller spec with a 54-byte executable path.
- **Acknowledging changed members costs one command per principle, not a lead and a command per member.** `list-member-problems` offers one acknowledgement per principle in `next_action`, in its JSON result and on `--short`'s stderr, `start-audit ID --member A --member B` naming every changed member a one-member audit may judge, after one lead saying when to audit that principle in full instead; it printed 13 command lines for nine members across three principles. A principle with a changed member no acknowledgement may judge still gets its full-audit command.
- **`list-member-problems --short` no longer repeats a commit's subject on every row it changed, nine times for nine members.** Each row is principle, id, newest commit and what it was compared with, then `waiting_on_an_upgrade` where it applies; the JSON result's `history` still gives the subject and earlier commits, and the after-commit hook's rows keep it.
- **Breaking:** a hook or heartbeat reading `list-member-problems --short`'s stdout and exit status no longer misses a member no audit has assessed, which was silent there until edited. It counts, after its rows, each principle's such members, as `ID<TAB>N never assessed`, and exits 3 for them as for a changed member, so exit 4, for edits only to such members, is gone; change any script that tests for 4. The session-start hook still leaves both out. An acknowledgement of a member whose check is `list-member-problems` is refused while that check counts such members, since its commit would not clear them.
- **Filling a full audit's template no longer risks overwriting a paragraph where an integer goes.** Its `check_result` placeholders say only what each field takes, and `exit_status` reads "the check's exit status, an integer", as a one-member audit's does. How to run and report the check, and how to word a review's basis, including your own review, is each checked member's `check_instruction` in the request's context, and `check_instructions` at the head of `start-audit --as template`.
- **Correcting a large full audit takes a template small enough to fill by hand.** The correction no longer hands the agent's own assessments back in its `basis`, about 9 KB: it reads them from the open audit record, and its `correction_template` carries only their digest, `assessment_report_sha256`. A correction whose open record was edited, discarded or restored to the completed one before it is refused, saying to start the audit again.

- **Correcting a full audit in git no longer hands the agent its assessment back.** The correction reads it from an open audit record that an assessment with findings now writes in git, as it already did outside git. Commit only a completed record: `start-audit` says when the record is open and how to discard it, and a one-member audit waits until the correction completes.

### Fixed

- **Two `bundle exec rake ci` gates run at once no longer build the gem over each other.** Each builds its package under a directory of its own in `tmp/`.
- **A served release is no longer checked with a query RubyGems answers 404.** `gem:publish` confirms it, where it checked the versioned download with a cache-bypass query that RubyGems answers 404 even for a served version (checked 2026-11-19 on 0.0.6). That is the likely cause of 0.0.5's and 0.0.6's `UNCONFIRMED`, put down then to slow propagation; the query is gone, and the SHA256 comparison still decides publication.
- **An agent on a loaded machine is no longer left unaware of a commit.** The plugin's after-commit hook reports it when Claude Code starts the hook up to 5 s after the Bash call ended, where it missed one from 2 s late; a commit made up to 6 s before the call began can now be reported a second time, by the next call.

## [0.0.6] - 2026-11-19

### Added

- **A full audit's correction is no longer lost before it is applied.** The submitted correction and its preview tell the agent to save the exact assessment and the correction packet before changing members, since git cannot rebuild the assessment's judgements; in git they also name the read-only `show-answer-check` command, which prints the correction again while the request's inputs are unchanged.

- **Merging or splitting principles no longer orphans an audited map's record.** `remove-principle ID` removes only the map, keeping its member files and audit history, and refuses without `--confirm` when the map has a current audit record, which it then keeps with its open findings.

- **A carrier that loads only under some paths is less likely to be mapped and then copied into a parallel version.** When an added member brings a Claude Code loading scope new to the map, `add-member` asks whether each carrier will be available where the principle applies, or should link to another. The scope is predicted from the paths, not observed delivery.

- **A rule that may be split across adjacent sections mapped under different principles, which no audit compares, is now flagged.** When an added member's Markdown section sits next to one mapped under another principle in the same file, and neither map has a completed full audit, `add-member` names both locations and asks whether they carry one rule or distinct principles.

- **A new map is no longer committed without asking whether it is complete.** For a map of one or two members with no completed full audit, `add-member`'s question also asks whether every carrier of the same rule is mapped and whether any member belongs to another principle, once per sitting.

- **Contributors wait about 2.3 times less for the unit checks.** `bundle exec rake spec:unit_parallel` runs them in three isolated groups at once, with complete failure reports, in about 7.6 s against about 17.4 s for `spec:unit`, in two samples.

- **Finding the carriers a survey left out no longer takes greps and header reads.** `show-candidate-outlines PATH...` prints the outlines of only the files it names, within the survey's output budget: in one case the survey had left 130 of 133 candidates at path and size, with both missed carriers among them.

- **A later session no longer repeats `--also` or rediscovers where its project keeps guidance outside the places hosts load.** `list-candidate-files` now includes the project's recorded guidance search paths with their match counts, and refuses a configuration it cannot use rather than silently dropping it.

- **Where a project keeps guidance outside the places hosts load, such as docs and runbooks, can be recorded once for later surveys.** `add-guidance-search-path GLOB` and `remove-guidance-search-path GLOB` write only the project's versioned `.principles/guidance-search-paths.json`, and an invalid, linked or newer configuration is refused and kept as it is.

- **A survey can now cover guidance kept outside the places hosts load, such as docs and runbooks.** `list-candidate-files --also 'GLOB'`, repeated for each location, outlines selected skill references, names other text files by path and size, and reports each glob's match count, zero included; it does not save the location, and ignored files stay unread.

- **A survey for extracting the principles a change landed no longer leaves out the change's own documents.** `list-candidate-files --commits-after REV` (REV a sha, branch or `HEAD~3`; needs git) lists first the files changed after REV, each marked `changed_in_range`, with any Markdown they changed outside the places hosts load. Past the output budget the range's outlines are cut only after every other file's are left out, and when they alone pass it the survey asks for a later REV rather than choosing which to drop.

### Changed

- **An answer recorded against a principle that was removed and recreated under the same id is no longer accepted.** An assessment or correction is refused when a commit since its base left the map's id absent, even when the map was recreated identically; unrelated commits are still allowed, and first-parent history git cannot give or verify is refused before any record is written.

- **Breaking:** recreating a removed principle's id now needs the removal committed first. `create-principle`, or the first `add-member` that creates the map, refuses while the map is still at committed HEAD and when git history is unavailable; once the removal is committed, the recreated map takes up its retained audit record as before.

- **A survey of a project that already has maps is less likely to lose how to continue under a long file inventory.** `list-candidate-files` now prints the survey's instructions, the existing maps' descriptions and the commands to choose from before the inventory.

- **Extracting principles in a project that already has maps no longer skips the survey.** `list-principles` now offers a general survey and one scoped to a change, and `create-principle`'s help and the Principles skill send the agent to survey, compare with the existing maps and audit new ones, where `list-principles` offered only `show-principle` and `start-audit`.

- **A candidate rule is less likely to be split into a new map when it belongs to an existing principle.** The survey gives each current map's id and description under `mapped_principles`, asks the agent to compare its candidate rules with them, and offers `add-member` for an existing principle beside `create-principle`; the table still comes before the questions.

- **Acknowledging one member takes a 260 B answer instead of filling a long form.** A one-member audit's template, in its request and under `start-audit --member --as template`, now prints only the fields the agent writes, and its question names what an answer may add (quotes, `basis.base_commit`, the check's `command` and `review_basis`), each read as the request printed it when left out. The check's run-and-report instructions moved to the request's `context.check_instruction`.

- **A checked member's acknowledgement has one integer to fill, not about 330 characters of prose to overwrite.** A one-member audit's template prints `check_result.exit_status` as "the check's exit status, an integer", and how to run the check and report it moved to `context.check_instruction`.

- **Acknowledging one member no longer means copying `base_commit` and the quotes back.** The answer may give only `request_id`, `basis.member_id`, `meaning_kept` and `reason`, and a checked member's `check_result` only its `exit_status`; what is left out reads as the request printed it, a quote given is still checked, and an answer to a request whose member changed since is still refused as `stale_request`.

### Fixed

- **A commit made in another checkout from one Bash call no longer goes unreported.** The plugin's after-commit hook now checks each directory the command `cd`s into or names with `git -C`, after the call's own, as in `cd CLONE && git commit`, and tells the agent which mapped members the commit changed. A target in one layer of single or double quotes is read without them; one holding a variable, a backtick or a backslash is not read, and when one call moves two mapped repositories only the first is reported.

- **A release can be confirmed later when RubyGems does not yet serve its upload.** `gem:publish` checks the exact versioned download up to 61 times, pausing 5 s after each 404, and when it still cannot confirm, or completion fails, it keeps the unconfirmed evidence and any newer local work for a later exact confirmation.

- **Copying an example into an audit answer no longer brings instructions with it or gets a sighting date refused.** The examples are kept apart from the prose that explains them, name where each goes and its alternatives, and use `null` for a current sighting.

- **An added or moved passage member no longer ends silently at the first match of an ending text that occurs more than once after its opening.** `add-member` and `move-member` refuse that ending before writing, saying how many matches overlap and where; existing maps and their evidence are read as before.

- **A correction that fixes a finding by removing obsolete members from the map can now be completed.** A fixed disposition may declare the exact members removed, and the correction completes, keeping their source files and the earlier findings and their ages.

- **A refusal over unverifiable first-parent history now names the right commit.** It named the current HEAD even when the history checked ended at an earlier one.

- **Commit ancestry can now be verified in a repository whose history holds a commit with unrelated author metadata that is not valid UTF-8**.

- Contributor-facing: a verified git snapshot stays fixed when a caller keeps its captured revision, so changing the SHA it exposes cannot point its guarded entry reads at another commit.

- **`remove-principle`'s help now says what removal does:** it deletes the map, which needs committing only if the map was tracked, and keeps the audit and member files.

- **New maps are no longer invisible to `list-member-problems --short`, which named never-audited older maps but not new ones.** Each map with no completed full audit is listed before the baseline guidance, an empty one asking for a member and the rest told to commit, then audit; exit statuses for changed members are as before.

- **A prepared assessment answer blocked by an uncommitted edit elsewhere in a file its members share is no longer lost.** The refusal says to commit the intended changes, then submit the same answer unchanged; a new audit still needs its files committed, and a stale answer is repaired as before.

- **A survey with `--commits-after` no longer leaves out what the change touched in mapped enforcement files and in Markdown references inside skills,** which it left out or counted only by directory. Unmapped application code stays outside the range's additional selection.

- **A survey's statement of what it covers is now complete.** It names the places hosts load by convention, the Markdown a commit range changed and the locations chosen explicitly, where it claimed only the conventional host files were listed.

- **Project text that happens to match the survey's internal JSON placeholder is now shown as written,** including a map's description printed before the file inventory.

- **A survey of a small change no longer wrongly reports its range's outlines as over budget.** They are reported over budget only when their own measured bytes exceed it, not because of a large unchanged entry file or list of uncommitted files.

- **Sending a checked member's `check_result.exit_status` back as its one-member template printed it is now told the field is still to write, beside `meaning_kept` and `reason`,** where it was refused as text with a repair offering a `not_run_reason` that template refuses.

- **A commit made at the very start of a Bash call is no longer missed by the plugin's after-commit hook.** The hook reads the clock a moment after the call ends, and the clock and the reflog's time count whole seconds, so it now counts a move from a second before the call's start; in exchange, a quick call made up to about two seconds after a commit can name its changed members again.

- **`list-member-problems`' `next_action` no longer reads as sending a checked member past the one-member audit offered just above.** It says a member needs a full audit when its check is new, changed or does not pass, where it said any member with a check did.

- **A passage member whose ending text is no longer in its file now gets a repair that can succeed.** `repair_with` names a `move-member` with `--ending-at NEW_ENDING_TEXT` to fill in, where it repeated the lost text, so the printed move failed the same way; the opening text is kept.

- **Session start and `list-member-problems` no longer slow down with each member a map gains.** They read the map and the members' file at the same commits once for every member, and now ask git once a command for each, and every member is read at the commit HEAD named when the command began, where a commit landing mid-command could leave some read at one commit and the rest at the next. The session-start hook's spec of a 21-member map fell from 3.6 s to 1.4 s.

## [0.0.5] - 2026-11-16

### Added

- **An agent reading a full audit's request can read any instruction it prints in part whole.** `start-audit ID --instruction FIELD`, such as `prior_findings_instruction`, prints every paragraph of a field the request trims, and the request names each trimmed field with that flag under `trimmed_instructions`.
- **A one-member audit's template can no longer acknowledge a change unfilled, and takes no script to get.** `start-audit ID --member MEMBER --as template` prints the answer alone, to fill with `meaning_kept` and `reason` and submit, and a template sent back as printed is refused, where `meaning_kept` printed `true` and so acknowledged the change without a judgement.
- **Quoting a one-member audit's change takes no hunt for the changed line.** The request prints `first_changed_lines`, the first line on each side of the change that the other side lacks, and on a line over 200 characters only the changed span with 30 characters either side.
- **Editing a checked member no longer forces a full audit when the check is the one the last full audit ran.** `start-audit ID --member MEMBER` acknowledges the edit with one passing run of that check, and `list-member-problems` offers it for such a member; a check new, changed, removed or reported not run since that audit still needs a full audit.

### Changed

- **Surveying a project's files takes no heading-grep script, which one agent wrote over 45 files.** `list-candidate-files` prints each listed Markdown file's `outline`: its headings in order, each one's top-level list items, a file's whole frontmatter `description`, and an `opening_line` of up to 160 characters, leaving out a file possibly test data. The survey question then asks the agent to name, under the table, the files that look ticket-local or boilerplate, with why.
- **A project survey spends less context on pretty-printing, which cost 17% of a 66 KB result on a project of 45 files.** `list-candidate-files` prints each listed file's entry compact on a line of its own and the rest pretty.
- **A project survey arrives in the conversation, where a project of 45 files' 41 KB had arrived as a saved file the agent scripted over.** `list-candidate-files` stays within 28,000 B, under Claude Code's inline limit for a tool result, by shortening outlines one step at a time across every file, keeping the root `CLAUDE.md` and `AGENTS.md` outlines whole, and naming under `inventory` each file whose outline it cut or left out.
- **A survey's opening lines are cut mid-clause less often: 30 of 45 had been.** `list-candidate-files` ends each `opening_line` at its last sentence end within 160 characters, or else on a word with "…".
- **A new project is surveyed, with the user shown one table, before any question is asked, rather than being asked to pick a principle first.** `list-candidate-files` has the agent read each listed file's headings and opening lines and show the principles they carry, and only then asks which to map, with the owner's questions about test data, ignored and untracked files.
- **Setting principles up is offered only after a first map and audit have shown their value.** A completed full audit's `next_action` ends by offering `show-meta-principle-passage` while principles is not set up.
- **A new project's first screens lead with mapping, not with setting principles up.** `list-candidate-files` and `list-principles` no longer lead with the "Set principles up first" line, `list-principles` with nothing mapped names `list-candidate-files`, and a completed audit offers setting up instead.
- **Breaking:** type `/principles` to start the plugin's skill, where it was `map-and-audit`, and expect it shorter. Its text is now a short mental model and its first command, `principles list-principles`, leaving the steps to what each command prints, and "What stays yours" is kept whole.
- **Changed members shown at session start or after a commit now send the agent to the `/principles` skill as where to start with them, where those reports had said the skill says how to audit them**.
- **A user whose PATH holds an older `principles` ahead of the plugin's now learns that a copy ran in place of the plugin's, where nothing said so.** The plugin's session-start hook says it in one line naming both versions and that copy's path, and stays silent when they match, when PATH has no other `principles`, or when the other prints no version.
- **The meta-principle passage is now asked to be placed as printed, after two sentences of an agent's own were added on a fresh install.** `show-meta-principle-passage`'s question asks the agent to place the passage exactly, adding nothing, and to say anything else, such as where only a reader enforces a step or how a teammate gets `principles`, in a sentence of its own after it.
- **Acknowledging a small change asks for under 4 KB of the member's file instead of reading it twice, about 19 KB for a one-line change to a short file of long lines.** A one-member audit's request now asks for it in under 4 KB, printing `member_lines` whole only within about 1.3 KB and otherwise the changed region with a line or more of context, and leaving out a side too long to print with `read_instead` to read it; the full audit's `acknowledged_since_last_audit` prints the same way.
- **A full audit's request leaves out the instruction paragraphs for cases that do not hold, so an agent reads only the guidance that applies.** Each prints only when its case holds, such as the definition of observed when a member is judged afresh, and `start-audit ID --instruction FIELD` prints any one whole; carried assessments stay carried.
- **A full audit's request spends less context on members nothing has flagged: 45 KB instead of 51 KB for 2 judged members and 9 carried.** The request prints each carried member no flag fires on as its `id`, `role`, any check and a few `carried_forward` fields, and one whose evidence or file changed, or on whose lines a finding is open, whole; `show-audit ID` shows each stored assessment.
- **An agent submitting an answer is no longer led to pass a principle id where the request id goes.** `submit-answer` and `show-answer-check` name it `REQUEST_ID` in usage, help and refusals, where `ID` and `REQUEST` misled, and a missing argument is refused once for all that are missing.
- **A mistyped field in an answer or record now draws a refusal that names the fields this tool reads in that place.** The refusal names the fields this tool reads in that place, such as `it reads command, exit_status and review_basis`.
- **A resumed session repeats less of the open findings its conversation already holds, where about 650 B were repeated.** The plugin's session-start hook prints at a resume a short line with the count, the oldest's age and name, and the `list-open-findings --short` command for the whole; `--session-start` takes `resume`.

### Fixed

- **An audit answer is repaired in one pass, not one refusal per problem.** An answer holding a field left as its template printed it, its own template's or another's, is now refused naming every other field its shape refuses too, such as `meaning_kept` given as `"true"`, and the message says it lists both.
- **Another template's placeholder text is no longer recorded as an agent's own words.** Any text some other template of this release prints is refused as that template's placeholder, whatever its ending, such as an acknowledgement whose `reason` was a correction's "Why, and what remains", which was accepted and recorded; an older template's lower-case `raised_in` placeholder is refused in the same one refusal.
- **Acknowledging a change to a checked member no longer loops on a repair.** The one-member audit template, filled as printed, is now accepted, where its `check_result` placeholders were refused as another template's.
- **A refusal message no longer repeats the answer file's absolute path.** Every refusal message that names the answer's file names the answer instead, the path stays in the refusal's `path`, and a missing `--file` says "The answer file does not exist".
- **A change can no longer be acknowledged by quoting a line it left alone.** A one-member audit's answer whose `old_line` or `new_line` both sides of the change hold is refused with a repair naming `first_changed_lines`, where a line a pure insertion left alone passed; "" is accepted for a side with no changed line.
- **A passage member whose opening text is gone from its file can now be repaired from the printed command.** The `move-member` that `repair_with` prints names `--starting-at NEW_OPENING_TEXT` to fill in, where it repeated the lost text and failed the same way, and a passage located by its opening text alone is repaired without `--section HEADING`.
- **Committing a completed audit as printed no longer leaves its changed map uncommitted** when the correction declared `moved_members`: `files_to_commit` and `commit_with` now name the map. The repair and the correction guide say that a move which kept the member's id is declared `{"from": ID, "to": ID}`.
- **A finding's opening and a long wait in the session-start line no longer end mid-word or at "(e.g.".** `write_up_opening` is cut at the first sentence end outside any parenthesis, and both are cut after the last whole word.
- **An agent whose commits changed only members waiting on an upgrade still learns how many other changed members are listed.** The after-commit hook's context gives the count and the command that shows each, as it does after other commits.
- **A full audit's guidance no longer leads an agent to write what the tool then refuses.** `answer_guide` shows a member check's `check_result` flat, as an answer gives it, `observed_at`'s placeholder for a dated record asks for 00:00:00Z, a prior finding's `action` placeholder is printed as a change, a decision that gives the action its finding already has is refused with a repair naming both ways on, and `ambiguous_passage` names the line of its first five matches and how many more.
- **A `check_result` given for a member with no check is refused with a repair that removes it, where the agent had been asked for a missing `command`.** The repair names each member that holds the principle's check.

## [0.0.4] - 2026-11-13

### Changed
- **A project's audit records survive upgrades between releases without silently losing fields.** From this release every record is written with its `format` and `format_first_release`, the release that first wrote that format, ahead of its other fields, so a later copy can refuse to rewrite a record it would lose fields from, as 0.0.1 dropped a finding's `reason` from a 0.0.2 record; a record without them reads as older than format 1.
- **Giving a new review line for a check no longer means adding a field by hand.** `start-audit --as template` prints `review_basis` for a check the last audit ran too: left as printed it keeps that audit's line and date, replaced it records a new one.
- **Raising a finding in a full audit no longer depends on a guide the template does not print.** `start-audit --as template` prints one finding to fill in `findings`, each field saying what it takes and its `proposed_action` that fixing, deferring or accepting it is the correction's; left as printed it raises none, and a finding otherwise filled is refused while a text field is left as printed.
- **Filling `start-audit --as template` takes one rule, stated once, instead of one per placeholder.** `start-audit`'s first step now says that a field the answer leaves as printed is read as omitted, where each placeholder said so in its own words.
- **A full audit's prior-findings template is about 40% smaller for three findings** (6,489 to 3,903 B; each decision 1,705 to 843 B). Each placeholder in `start-audit --as template` now says only which decision takes it and what, and "else kept" where leaving it keeps the finding's. An answer that leaves a 0.0.3 template's placeholders in place is not read as leaving them.
- **Giving a prior finding's evidence no longer means guessing its shape.** `start-audit --as template` prints each prior finding's `evidence` and `problem_evidence` as one pointer to fill, `problem_evidence`'s with `replaces` as a key, where each printed as a line of text; `start-audit`'s first step says once that a field saying "else kept" keeps what it had when left as printed, and null drops it.
- **A filled answer no longer needs `start-audit`'s help to know how a field left as printed is read.** Only that help, which the agent filling the template does not read, said it; the template now states it once, in `left_as_printed_rule`, which the answer may send back and which is never recorded. Each prior finding's decision field now says what to do when its decision does not take it, `replaces` left as printed is refused as such, and `start-audit`'s first step asks for your own judgement rather than filling by hand.
- **Mapping several members in one sitting uses about 700 bytes less of context for each member after the first.** `add-member` prints its reminders, to commit the map, how to show it and the next step, only with a principle's first member or, in git once it has a commit, while the map file is as last committed; its help says so.
- **Filling a correction from `submit-answer` no longer means guessing what each `action` may be.** `submit-answer` and `show-answer-check` print one correction template, each `action` its placeholder naming the four actions and what each adds, where `submit-answer` printed it null.

### Fixed

- **`rake gem:publish` now refuses to upload a gem holding a harness component.** The gem is packaged from an allowlist, its executable, Ruby, data and schemas and the prompts it prints, and `rake gem:publish` refuses, before any upload, a built gem holding a harness component such as a `CLAUDE.md`, a skill or a hook script, naming each; this is a packaging guard, since the gem carries the CLI alone.
- **An audit can no longer be completed with another template's placeholders recorded as a finding's problem and whom it waits on.** An assessment or correction answer holding another template's placeholder in any field, free text included, is refused in one `invalid_answer` naming every field, where such an answer, repaired field by field, completed the audit; text is read as a placeholder by its ending, so reword the ending of text that is your own.
- **Readers of the plugin's copy of `CHANGELOG.md` can follow each commit and ticket it names.** Each now links to this repository on GitHub, where its links relative to this repository resolved nowhere inside the marketplace's plugin folder.
- **An answer that names another request is refused up front, instead of being repaired field by field.** Every phase of `submit-answer` and `show-answer-check` refuses it as `request_mismatch`, and one for a record a later copy wrote as `newer_audit_record`, before the rest of its shape.
- **An answer filled from another template now says to start from this request's `response_template`,** where the refusal printed the field's pattern: a `raised_in` that is neither a full sha nor this template's placeholder, as such an answer leaves it, is refused as not this template's placeholder.
- **An assessment answer whose request no longer matches the project now says so first.** `submit-answer` and `show-answer-check` refuse it as `stale_request` before the rest of its shape is read, where a field the template said to leave as printed was refused first with this release's placeholder pattern (an older template's answer to a request that still matches is still refused so); `stale_request` names another release or checkout of principles among its causes.
- **Whether `list-member-problems --short` exit 0 means all clear is now stated, not inferred.** Its help and the `principles:map-and-audit` skill state that `--short` exits 0 while every change waits on an upgrade, since no audit can act on one until then, where only the help's "only waiting rows" implied it.
- **A principle whose audit record a later copy wrote is now told apart in `list-principles`,** where its row looked like any other, or was a bare refusal: it shows `record_waiting_on_an_upgrade` beside it, its `format` and `format_first_release`, with its members counted against the hashes that record holds even where this copy cannot read the rest of it. `next_action` names those principles, says once how to update and offers `start-audit` only while another is left to audit, where it offered one `start-audit` refuses.
- **A commit that changed a member whose audit waits on an upgrade no longer sends the agent to audit it.** The after-commit hook's context names that member apart from those to audit, with the line saying why and how to update.
- **Mapping several members in one sitting no longer repeats how a fix claims the new member while a correction may be open.** `add-member` prints it only with the other once-per-sitting reminders, on the first add-member since the map was last committed, where each member mapped in one sitting repeated it.
- **One unreadable audit record no longer hides every other principle's open findings.** `list-open-findings` and its `--short` line list the open findings of every principle this copy can read, leave out a record a later copy wrote that it cannot, name it under `records_waiting_on_an_upgrade`, and refuse it only when its principle is named, where it refused for that one record and the session-start hook said the command failed.
- **`show-audit` of an audit record a later copy wrote now says why it cannot act on it.** It shows `record_waiting_on_an_upgrade`, saying its audits and acknowledgements wait on an upgrade and how to update, where only `start-audit`'s refusal said so.
- **A record a later copy wrote no longer blocks the check of every member, or leads to audits this copy would refuse.** `list-member-problems` and its `--short` stderr name each such principle under `records_waiting_on_an_upgrade`, saying its audits and acknowledgements wait on an upgrade and how to update, and compare its members read-only with the hashes that record holds, even where this copy cannot read the rest of it; each changed one is marked `waiting_on_an_upgrade`, in `--short` in a sixth field, with no audit offered, so an edit to one still shows. `--short` exits as the other principles leave it and does not say no principle is mapped, and the session-start hook prints the line, where it offered audits this copy would refuse, or refused the whole check when this copy could not read the record.
- **A later copy's audit record is no longer rewritten by this release, dropping fields it does not know.** `start-audit`, with `--member` and `--write-ups` too, and again `show-answer-check` and `submit-answer`, each reading the record afresh, refuse a record at a newer format as `newer_audit_record`, naming the release that first wrote it and saying to leave the record as it is.
- **A newer audit record is no longer reported as broken.** Every command that reads one this copy's schema cannot read refuses it as `newer_audit_record`, where it was refused as `invalid_audit_record` with a repair to fix or restore a record that is not broken.
- **One refusal, instead of one at a time, now names every judgement left as `--as template` printed it.** It names an observed member's `observation` and a `recent_decision` with both forms left as printed, beside the assessments, where each took its own refusal in turn.
- **The same refusal now names each prior finding whose `decision` is left as printed,** where a second submit refused it as `invalid_decision`.
- **An answer whose keys are reordered, as `jq -S` does, is accepted.** The request id digested its basis in printed key order and refused it as `stale_request`; request ids printed by 0.0.3 no longer match, so start an audit again after upgrading.
- **A correction answer whose `basis` was edited is refused for what it is.** It is refused as `invalid_answer` at `/basis`, where it was refused as `stale_request`, which said the project had changed and to start again.

## [0.0.3] - 2026-11-12

### Added

- **A release's dated history is cut with one command.** The person publishing runs `rake changelog:cut`, which moves the curated Unreleased entries under `## [RELEASE] - <today>` and refuses an empty Unreleased or a version already cut, so the gem and the plugin publish from one dated history.

### Changed

- **A gem release can no longer go out without its dated changelog section, and the plugin shares that one history.** Root `CHANGELOG.md` is now the plugin's changelog too (the plugin build copies it, `plugin/CHANGELOG.md` is gone, and a plugin publish needs the version's dated section), and `gem:publish` refuses a candidate whose section is missing or not dated today, and no longer edits a changelog after upload.
- **Reporting an observed delivery in a full audit takes fewer edits.** `start-audit --as template` prints `observation` and `observed_at` beside each fresh member's `delivery`, so an agent fills placeholders instead of adding fields.
- **A plugin user can see how to install it.** The plugin's README now gives the install line, the `/plugin install` command, which Claude Code's plugin validation asks for.

### Fixed

- **An agent that adds a member as a correction's fix is told how to record it, not only offered a fresh audit.** `add-member`'s result says that, in git once a commit holds the map with the member, the member is named in the fixed disposition's `changed_members` and the correction submitted.
- **Fewer wrong turns filling a new or changed check's `exit_status`.** Its placeholder now says the commit that set or changed the check and that `show-audit` prints the command the last audit ran, where it pointed at `context.members`, which `start-audit --as template` does not print.
- **A placeholder can no longer be stored as an audit's judgement.** A full audit answer that sends back a member's `assessment` or the `collective_assessment` as the template printed it is refused, naming every such field in one refusal; a correction already refused its own.

## [0.0.2] - 2026-11-12

### Added

- **A Claude Code user can install `principles` and see what changed in the guidance the agent reads, without running a command.** The `principles` plugin, first written to its plugin marketplace as this release, carries the CLI with its `map-and-audit` and `setup-ruby` skills and a SessionStart hook that puts changed mapped members into context at startup, resume, clear and compaction; a hook after each Bash call does the same when the call committed, amended or merged, and is silent otherwise.
- **Publishing the gem checks it before the next patch version is prepared.** The person publishing runs `rake gem:publish`, which keeps the built artifacts and confirms their checksums before preparing the next patch version.
- **Contributors are asked to keep the changelog current as changes land.** A mapped practice for maintaining the changelog now sits among the project's principles, held like the others.
- **An agent can fill a full audit's answer without writing its shape from memory.** `start-audit ID --as template` prints the answer alone, to save under `$TMPDIR` and fill, each placeholder saying what its field takes, including the allowed values of each prior-finding and loading decision.
- **An agent whose full audit found problems gets the correction's answer ready to fill.** `show-answer-check` prints `correction_template` for an assessment with findings, with its request id and basis digests filled in and each action naming the four to choose from, so only its dispositions are left to fill before submitting it after the assessment.

### Changed

- **Reporting a check's result in a full audit takes one placeholder replaced, not a field added.** `start-audit`'s template starts a checked member's `check_result` with `exit_status`, whose placeholder says how to run and report the check, beside `not_run_reason`; a field left as printed counts as not given, a check no audit ran gives `review_basis` to fill too, and an unfilled `exit_status` or `review_basis` is refused by name.
- **An agent answers a prior finding by replacing placeholders alone.** `start-audit --as template` prints each field a prior finding's decision may give with its own placeholder saying which decisions take it, including everything `still_holds` may give; a field left as printed counts as not given, so leaving `waits_on` as printed keeps the ask. `recent_decision` prints both its forms the same way, and each `loading_decisions` entry prints a `reason` to fill.
- **A finding whose term was renamed can have its problem restated.** A `still_holds` decision can restate the problem of a prior finding whose record states one, when a term in it was renamed or a fact it names moved; the finding keeps its id and `first_raised_at`, and the completed result names each restated problem, as it was and is now, under `prior_findings_problems_restated`.
- **An agent told of changed mapped members is pointed to the skill that says how to audit them.** The session-start and after-commit hooks' reports name the plugin's `map-and-audit` skill; quiet output is unchanged.
- **The plugin's skill is loaded when principles come up, with a shorter always-loaded description.** The `map-and-audit` skill's description asks the agent to load it when the user mentions principles, wants a rule to always hold, asks why guidance drifts, or a mapped file is about to change, and the description loaded in every session is shorter.
- Contributors: loading aggregates are attributed to their documented host assumptions, without reopening existing audit evidence.
- Contributors: bounded UTF-8 member reading now lives in one data owner, with local-member behaviour unchanged.

### Fixed

- **A correction that defers, accepts or disagrees no longer needs fields only a fix uses.** Such a disposition may omit `changed_members`, `evidence` and `reassessment`, which was refused as `/dispositions/0/changed_members is required`; a `fixed` disposition missing one is still refused, naming it, and a reassessment or evidence on any other action is refused rather than dropped. The correction template's `action` and `reassessment` placeholders now say so.
- **A finding's reason for deferring, accepting or disagreeing is no longer lost.** The `reason` a correction gave is kept in the audit record and printed in `list-open-findings`, and the next full audit keeps it with the finding, or takes the new reason a `still_holds` decision gives with a new action; a fix keeps its reassessment instead. An older copy of `principles` that rewrites the record drops the field, until that is fixed.
- **A reason that would have been silently dropped is now refused.** A `still_holds` decision that gives a `reason` but changes no `action` is refused, saying to restate the finding with `problem`.
- **`start-audit`'s help no longer misleads about whose evidence a prior finding carries.** It now says a prior finding's evidence is the listed finding's, and that only a `resolved` decision may give evidence of its own.
- **`principles` run from a nested directory finds the project's store.** It reuses the nearest project store while keeping explicit independent projects and Git worktree boundaries apart.
- **A project that has mapped its meta-principle is still pointed at its first own principle.** The setup cue to map a first own principle survives the meta-principle's mapping.
- **A team enabling the plugin in a committed setting learns what teammates need.** Setup and help now say marketplace access is required for the committed plugin enablement setting to help teammates.
- **A short check's exit statuses are described correctly in help.** Help now distinguishes the exit status for a change that was assessed from one never assessed.
- **An agent finishing an audit is prompted to review the project's own rules before committing, and `submit-answer`'s help says accurately what it writes.** The help states the boundary between audit-record writes and member guidance, where it falsely claimed it wrote no project files, and the commit recipes now come after a prompt to review each diff and follow the project's verification and commit-message rules.

## [0.0.1] - 2026-11-10

_Initial RubyGems release._

### Added

- **A project can map each principle to every place that carries it.** Members are mapped by file, Markdown section or passage, and supported structured selectors.
- **A project can tell when the guidance carrying a principle has drifted.** Mapped members are audited, findings retained and changes acknowledged, with agent judgement kept apart from deterministic validation.
- **Installing needs only Ruby.** The standalone `principles` command runs on Ruby 3.4.2 through 3.4.x with no runtime gem dependencies.

[0.0.1]: https://rubygems.org/gems/principles/versions/0.0.1
