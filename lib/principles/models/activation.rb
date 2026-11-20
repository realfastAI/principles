# typed: strict
# frozen_string_literal: true

require_relative "../error"

module Principles
  # The domain logic, and the mediation of persistence. models/CLAUDE.md owns the boundary.
  module Models
    # When a principle's work is in hand, as the agent judged it: when files matching its globs are read or
    # changed, when its work is invoked, or always. This tool stores what the agent declared and does not choose it.
    class Activation
      FORMS = "Give exactly one of --when-files GLOB (repeat it for each glob), --when-invoked, or --always."

      # The activation change-activation's options declare, refused unless they name exactly one form.
      #: (when_files: Array[String]?, when_invoked: bool?, always: bool?) -> Activation
      def self.declared(when_files:, when_invoked:, always:)
        given = { "files" => when_files, "invoked" => when_invoked, "always" => always }.compact
        unless given.length == 1
          raise Error.new("invalid_activation", "change-activation needs one activation, not #{given.length}", FORMS)
        end

        globs = when_files
        return new({ "when" => given.keys.first }) unless globs

        new({ "when" => "files", "files" => globs })
      end

      #: (Hash[String, untyped]) -> void
      def initialize(fields)
        @fields = fields.freeze #: Hash[String, untyped]
        check_globs
        freeze
      end

      # The activation as the map stores it.
      #: () -> Hash[String, untyped]
      def to_h
        @fields
      end

      # What a full audit lists against this activation for the agent to weigh: the members that load at every
      # session start under a files activation; none under always, where the work is in hand in every session; and,
      # under invoked, a listing not built yet.
      #: () -> String
      def full_audit_lists
        case @fields.fetch("when")
        when "files" then "session_start_members"
        when "invoked" then "not_built"
        else "none"
        end
      end

      private

      #: () -> void
      def check_globs
        return unless @fields.fetch("files", []).any? { |glob| glob.strip.empty? }

        raise Error.new("invalid_activation", "an empty glob matches no file",
                        "Give each --when-files a glob such as 'spec/**'.")
      end
    end
  end
end
