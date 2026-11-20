# typed: strict
# frozen_string_literal: true

require_relative "invocation"
require_relative "prompts"

module Principles
  # What this tool prints, from plain values a controller hands it. views/CLAUDE.md owns the boundary.
  module Views
    # The offer of the hook entries that report changed members between audits without the principles plugin, which
    # a completed audit and show-meta-principle-passage both make while principles is not set up.
    class ReportHooksOffer
      #: (Invocation) -> void
      def initialize(invocation)
        @invocation = invocation
        freeze
      end

      #: () -> String
      def to_s
        Prompts.text("set-principles-up/offer-the-report-hooks", command: @invocation.in_project("show-hook-setup"))
      end
    end
  end
end
