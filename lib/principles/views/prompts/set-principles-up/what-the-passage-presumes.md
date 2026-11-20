The passage asks its steps only where `principles` is installed, so a teammate without `principles` is told to do
nothing it cannot, but still loads its %{estimated_tokens} estimated tokens in every session that loads the entry
file. Nothing runs the steps for that teammate: the plugin's session-start hook reports only in sessions where the
plugin is enabled, and whether a teammate's sessions have it is something this tool cannot see.
