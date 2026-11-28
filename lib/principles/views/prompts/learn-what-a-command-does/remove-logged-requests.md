Use it when `show-logged-requests` shows the folder holding more sessions than you still need: each request copies
the session's whole context, so old sessions fill the disk and keep old context on it.

`--keep-sessions N` says how many of the newest sessions to keep, a whole number, 0 keeping none; without it, 5.
It refuses with `invalid_keep_sessions` any other value. Before deleting anything it also refuses with
`request_logging_unguarded` while the folder exists without its `.gitignore`, and with
`request_logging_not_ignored` while git does not ignore every file there.

It ranks the sessions by their newest line in `requests/index.jsonl`, comparing the timestamps as text, and deletes
the request and response files the index names for every session older than the newest N. It keeps the index, the
launch file, any file a kept session also names, and any file the index names outside `requests/`. It also deletes
each request file the index does not name, which `show-logged-requests` counts as `orphan_requests`, once it was
written before every kept session's file; with `--keep-sessions 0` every such file stays, since one may belong to a
session still running.

Its result lists what it deleted under `removed`; `wrote` is empty.
