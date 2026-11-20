`version_at_last_audit` is the version of `principles` this principle's last completed audit ran under, or null when
no completed audit recorded one, and `version_now` the version running now. A new version can change the session-start
hook, the skill and the passage `show-meta-principle-passage` proposes, %{mapped}.
`passage_changed` says whether that passage's text changed since, or is null when there is nothing to compare it
with. The project's passage may differ from the one setup proposes, on purpose: placed in its own words, with a step
left to a section that already carries it. So when the version or the passage changed, compare what each says the
keeping needs, not their words, and raise a finding only where the project's passages no longer carry a step the
keeping needs. The release that replaced setup's earlier passage forms with one short passage reports
`passage_changed` true once, at the first audit after it, whatever the project placed; that report is expected.
Setup writes nothing once this principle is mapped, and prints its passage under `passage`: %{setup}
