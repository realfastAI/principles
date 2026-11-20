Use it when a principle's practice matters only for some of the work, such as a testing practice that matters
only while specs are being written, so you can later see which of its members load into every session anyway.
Each member's text costs context in every session it loads in, whether or not its work is in hand.

Give exactly one form:

- `--when-files GLOB`: the work is in hand when files matching the glob are read or changed. Repeat it for
  each glob, for example `--when-files 'spec/**' --when-files 'lib/**/*_spec.rb'`.
- `--when-invoked`: the work begins at a moment, as a skill or a runbook is invoked, not on files.
- `--always`: the principle holds for all work, in every session.

This tool records what you judged in the map, under `activation`. The result prints that activation, not the whole map;
show-principle prints the map with it. It replaces any activation set before; when the map already holds the one you
give, it writes nothing, says so and lists no file in `wrote`. It refuses no form, more than one, or an empty glob with
`invalid_activation`.

Under a files activation, start-audit's next full audit lists each member that loads at every session start anyway,
and asks you to decide each one in `loading_decisions`; its help says how. It also names the members this tool knows
no carrier for, which an `@` import may still load, without asking for a decision on them. Not built yet: listing
members that load on files, skills or agents and any listing under `--when-invoked`. show-principle prints each
member's own size beside its file's.
