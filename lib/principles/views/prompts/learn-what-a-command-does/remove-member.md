Takes MEMBER out of principle ID. MEMBER is the id `show-principle` lists. The member's file is not
touched. It prints the id it removed as `member_removed` and how many members are left as `members_left`, not the
map; `show-principle ID` lists them.

An id no member has is refused with `unknown_member`. When it differs from one mapped id only in case, spacing, dashes
or quotes, or is the heading or passage of exactly one mapped id given without its path, the refusal names that id under
`did_you_mean` and starts its repair with this command run on it instead. This tool never acts on the near miss: check
that it is the member you meant before you run it.
