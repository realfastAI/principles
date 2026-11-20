Lists every mapped principle, with its members counted by whether they changed since the last audit.
Run it to decide which principle to look at or audit.
To say what principles are in place and what each still waits on, give `--open-findings`, rather than joining
this list with `list-open-findings`: each row adds `open_findings`, one line per finding its last completed audit
deferred or accepted, with its id, whom it waits on, or that it is accepted, and how many days it has been open.
With nothing mapped, `next_action` names `list-candidate-files`, which surveys the project's principles for the user.
When the `sticking-to-your-principles` map has no members, its row adds `no_members`: setup no longer writes
that map before its first member, so an earlier setup, or removing its last member, left it. It names the map's
file to remove, and the command whose printed add-member adds its first member.
When a later release of principles wrote a principle's audit record, its row adds `record_waiting_on_an_upgrade`,
the record's `format` and `format_first_release`. Leave its record as it is. `next_action` names those principles,
says once how to update, and offers `start-audit` only while one is left that does not wait.
