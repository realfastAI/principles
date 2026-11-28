A member can be mapped and audited yet never reach the agent, or reach it in every request at a cost nobody
chose. This command is for seeing what actually reached the context: it reads the logged requests and
reports which mapped members' text each one holds. It writes nothing.

A captured request holds the session's whole working context and the user's account email, and the host writes its
file readable by other local users, so the command reads none while git might commit one. It refuses with
`request_logging_unguarded` while the folder's `.gitignore` is gone, and with `request_logging_not_ignored` while git
does not ignore every path there.

It runs `jq` and `rg` over the captured requests, with no slower fallback. While either is not on PATH it
refuses with `fast_tools_missing`, naming the missing tool and what it does here; ask the user before
installing it, then run the command again.

It opens with `members_by_status`, how many members have each status, every status named. Then it prints
`members`, one entry per mapped member: its `principle`, its `member` key, then, for a member moved since it was
mapped, its `id`, where it is now, since its key names where it was, then its `status`, the `seen_in` requests that
held its lines, its `most_bytes` in one, and the `segments` it was seen in. That stays within a tool result however
many requests are logged. `--places` prints instead, under `seen`, each place its lines were found, which grows with
every request, and `--member KEY`, given once a member, the same for those members alone, refusing a key no map holds
as `unknown_member`, with any key it is spelled like as `did_you_mean`: the `request` file, the `query_source` the host's index gives it, the
JSON `path` inside the request, the `segment` (`reminder` inside a system reminder, `plain` elsewhere), the
`share` of the member's lines found there, the `count` of their occurrences there, the `offsets` at which each
starts, in bytes into the string at `path`, and their `bytes`, every occurrence counted, since a line sent twice
costs its bytes twice. A member is measured by its lines of 24 bytes or more, with leading indentation stripped.
While requests are logged here, `list-member-problems` names each member with no such line under
`too_short_to_scan`, an `unmeasurable` one here, with the `move-member` that widens it. `orphans` counts the
captured requests the host's index gives no `query_source`, since it writes an index line only once the response
succeeds. `quoting_requests` names the
requests that name a captured request file, where the agent read or named one, so what was seen there may
be a quote of an earlier request rather than what the host loaded. `unreadable` names each request the scan could
not read, by its `request` file and its `reason`: `not_whole_json` for one that is not whole JSON, such as one a
host left truncated, and `not_decoded` for whole JSON the scan stops at, such as a list rather than a request,
or a request the scan did not decode to its end, such as one the host rewrote while it read.
Such a request is not scanned at all, rather than in part, so a member it held is not counted.
`completeness` says how much the scan read: the requests `captured`, those under `unreadable` too, the `leaves`,
strings, in those it decoded, and `complete`, true only when it read every request through. A full audit's
`requests` and every `seen_in` count only the requests read through, the captured ones less the unreadable. Read an
`absent` as proven only while `complete` is true.
Nothing from a request's text is printed, and `wrote` is empty.

`--short` prints lines instead of JSON, and no `status_meanings`, to read before or in place of the whole result: first the counts by status,
then the requests captured, whether the scan was complete, how many requests were unreadable and how many quote a logged
request; then one tab-separated line a member, with its status, principle, member key, followed by `(now ID)` once
moved, and the segments it was seen in,
or `-` for none.

`status_meanings` says once what each `status` means, `not_a_carrier` first. A full audit's `logged_requests` part
prints it too.
