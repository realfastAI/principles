Remove a recorded survey location when it no longer identifies this project's guidance. Use the exact normalized
glob from `recorded_guidance_search_paths`, not a member id or text location.

%{executable} remove-guidance-search-path 'guides/**/*.md'

Writes only `.principles/guidance-search-paths.json`; commit it. The last removal retains a valid empty configuration.
The result gives the remaining `recorded_guidance_search_paths`, its `wrote` file and a read-only survey in `next_action`.
It never removes guidance files, principle maps or audit records. Later surveys automatically use the remaining
recorded locations; a removed glob stops that extra selection, while conventional and temporary selections still apply.

An absent selection is refused as `unknown_guidance_search_path`, with the recorded list to choose from, without
creating configuration. Invalid globs, malformed or newer configuration, linked files and I/O errors are refused
as add-guidance-search-path describes; restore or upgrade the store instead of replacing its contents by hand.
