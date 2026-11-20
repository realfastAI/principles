Maps a new principle under ID, a lower-kebab-case name for it, with TEXT saying what the principle is
and why it matters. The map, `.principles/maps/ID.json`, holds that description and the members you add;
commit it as it changes.

If this ID's map was removed or changed to another ID, commit that removal before recreating it. A map still
present at committed HEAD refuses with `map_removal_not_committed`, even if its old contents are unreadable.
Unavailable Git history refuses with `git_history_unavailable`; restore access and retry. Healthy projects
outside Git can still create maps. Before a repository's first commit, verification needs Git supporting
`show-ref --exists`; otherwise make an initial commit or upgrade Git, then retry.

`sticking-to-your-principles` is refused as `meta_principle_id`: run `show-meta-principle-passage`, whose
printed `add-member` creates that map with its first member.

Before choosing its members, survey the guidance if you have not already, comparing the existing maps before
creating another. To survey the project:
%{executable} list-candidate-files

To survey the principles a committed change carries, name the revision before it:
%{executable} list-candidate-files --commits-after REV

A surveyed rule that is a facet of an existing principle belongs in that map; add-member adds another place
carrying it. A distinct principle starts with create-principle, then add-member and its first full audit.
