The `-m` message in `commit_with`, "%{subject}", is a default: replace it with a subject in your project's own
convention, such as a ticket prefix, before running it, since a commit hook may refuse the default. For a message with
a body or trailer, write it to a file and put `-F <file>` in place of `-m` and its subject; a file needs no shell
quoting, and a relative path to it resolves from the project, which the command changes into first.
