# typed: strict
# frozen_string_literal: true

require_relative "invocation"

module Principles
  # What this tool prints, from plain values a controller hands it. views/CLAUDE.md owns the boundary.
  module Views
    # The notice start-audit adds about the principle's last audit record, beside a full audit's request: a record
    # left uncommitted, or one holding an open audit.
    class LastRecordNotice
      #: (Invocation) -> void
      def initialize(invocation)
        @invocation = invocation
        freeze
      end

      # The notice start-audit adds when the last audit's record is not committed.
      #: (String) -> String
      def uncommitted(file)
        "The last audit's record, #{file}, is not committed. Commit it, so the project keeps it."
      end

      # The notice start-audit adds, in git, when the last audit's record is open: its correction completes it, so it
      # is never committed.
      #: (String) -> String
      def open(file)
        "The last audit's record, #{file}, holds an open audit, waiting on its correction. Do not commit it: submit " \
          "that correction, or answer this request, which replaces it, or discard it with `git restore #{file}`."
      end

      # The notice start-audit adds while principle_id's last audit is open and keeps its correction: the command that
      # prints that correction again, to resume it.
      #: (String) -> String
      def resume(principle_id)
        "The last audit of #{principle_id} is open, waiting on its correction. To resume it, print that correction " \
          "again: #{@invocation.in_project("show-open-correction", principle_id)}"
      end
    end
  end
end
