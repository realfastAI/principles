Deferred with recorded_at null: %{finding_ids}. That is allowed when there is nowhere to point; the record then
keeps no pointer, so list-open-findings prints no write-up. If one is written up in a project file, point its
recorded_at there and check again; if it is written up outside the project, such as in an issue, set its recorded_at to {"url": ...} with the link.
