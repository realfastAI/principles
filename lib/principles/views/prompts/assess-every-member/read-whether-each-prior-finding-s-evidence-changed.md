Each item of a prior finding's `evidence` carries `changed_since_last_audit`: whether the text it points at reads
otherwise now than at %{commit}, the commit the audit that last raised or kept the finding was based on. It is also
true when the item cannot be found then or now. False says only that those lines read the same, so less needs
reading again: a member's other lines, as `members_since` shows, or text elsewhere may still have resolved the
finding, and whether it still holds is yours to judge. A file outside the map may have differed from that commit
when that audit read it.

Beside it, `found_now` says whether the item resolves now. False means its text was removed or moved, so find where
the problem lies now, if anywhere, before you judge the finding. If it still holds there, decide it `still_holds` and
give `problem_evidence` with one entry per item no longer found: its new pointer, and `replaces`, that item's position
in `evidence`, counting from 0. This tool checks again that the item is not found, and refuses an entry for one still
found; the other items stay as they are. True with a change means judge the finding against the text as it reads now.
