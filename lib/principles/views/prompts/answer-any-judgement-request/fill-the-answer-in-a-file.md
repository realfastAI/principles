Save the answer alone in a file outside the project, such as under $TMPDIR: %{save} > FILE

Fill %{what} with your own file-edit tool, not a shell heredoc; JSON escapes only a double quote, a backslash and a line
break, as \", \\ and \n, never an apostrophe.

Submit that file: %{answer_with}
