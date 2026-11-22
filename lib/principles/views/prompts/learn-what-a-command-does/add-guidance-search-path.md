After showing the user the principles table, save where to look for this project's agent instructions and checks.
A guidance search path selects files for a survey; it does not map a principle or establish host delivery.
Use list-candidate-files --also with a quoted project-relative file pattern to try a selection before recording it.

%{executable} add-guidance-search-path 'guides/**/*.md'

Writes only `.principles/guidance-search-paths.json`, in the selected project's store; commit it as it changes.
The glob is normalized as --also normalizes it. A duplicate addition returns `unchanged` with an empty `wrote` list
and leaves existing bytes untouched. `recorded_guidance_search_paths` gives the normalized stored list; `next_action`
prints a read-only survey of just the files an added glob matches, with list-candidate-files --only, since the rest
were surveyed before; later surveys automatically include recorded locations without repeating --also.
No map, audit record or guidance file is changed, and nothing is executed.

Blank, absolute or parent-traversing patterns are refused as `invalid_guidance_search_path`. Invalid JSON or schema
is refused as `unparseable_guidance_search_paths` or `invalid_guidance_search_paths`; `newer_guidance_search_paths` asks for
an upgrade while preserving the newer file. A linked store or configuration is refused as `symlinked_directory`
or `symlinked_guidance_search_paths`, including a dangling link. `guidance_search_paths_io_error` reports an unreadable
or unwritable store; repair it before retrying. A missing file is an empty list, not a reason to hide an access error.
