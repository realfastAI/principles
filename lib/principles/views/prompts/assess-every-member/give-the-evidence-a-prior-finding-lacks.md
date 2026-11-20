A finding marked `evidence_not_kept` has a record that keeps no evidence, as one written before this tool kept a
finding's evidence. Its `evidence_request` asks for it, and its decision in the template starts with an empty
`problem_evidence` list. Pointers given there, as a new finding's `evidence` gives them, become its evidence in the
record, so another principle's audit that shares these lines can tell whether the finding is about the lines it
shares. Left empty, on any decision, the list gives none, and a `still_holds` decision is still accepted. This tool
checks only that each pointer resolves now, not that it points at the problem. A finding whose record keeps its
evidence takes `problem_evidence` only to re-point an item no longer found, each entry naming it by `replaces`.
