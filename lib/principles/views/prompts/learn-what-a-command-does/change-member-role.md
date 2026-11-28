Replaces the role of MEMBER of principle ID with ROLE. MEMBER is the id `show-principle` lists. The result prints
under `member` its id and new role, not the whole map: `show-principle` shows the rest.

Run during a full audit, between an accepted assessment and its correction, to fix a finding in the map: list MEMBER
in the `changed_map_entries` of the fixed disposition it fixes, and submit the correction. This tool prints both
that step and starting the audit, since it cannot tell in git whether a correction is open.

An id no member has is refused with `unknown_member`. When it differs from one mapped id only in case, spacing, dashes
or quotes, or is the heading or passage of exactly one mapped id given without its path, the refusal names that id under
`did_you_mean` and starts its repair with this command run on it instead. This tool never acts on the near miss: check
that it is the member you meant before you run it.
