# typed: strict
# frozen_string_literal: true

require_relative "visible_text"

module Principles
  # What this tool prints, from plain values a controller hands it. views/CLAUDE.md owns the boundary.
  module Views
    # One changed member as a line of tab-separated fields, each written through VisibleText: its principle, id,
    # newest commit that changed it (or "uncommitted", or a plugin's "version:" installed), that commit's subject, and
    # what it was compared with: "audit", "mapping_commit" or "pinned", then "waiting_on_an_upgrade" for one compared
    # with hashes a later copy wrote.
    # The after-commit hook prints it, and list-member-problems --short its short form, without the subject.
    class MemberRow
      # member is one entry of list-member-problems' "members", with its "history".
      #: (Hash[String, untyped]) -> void
      def initialize(member)
        @member = member
        freeze
      end

      #: () -> String
      def to_s
        history = @member.fetch("history", {})
        newest = history.fetch("commits", []).first
        joined([*head, newest ? described(newest, history) : "not committed yet", *tail])
      end

      # The row without the commit's subject, which repeats on every row one commit changed and which
      # list-member-problems' JSON keeps.
      #: () -> String
      def short = joined([*head, *tail])

      private

      # The principle, id and newest commit that changed the member, or "uncommitted", or for a plugin's member, which
      # no commit changes, the version installed now.
      #: () -> Array[String]
      def head
        newest = @member.fetch("history", {}).fetch("commits", []).first
        [@member.fetch("principle"), @member.fetch("id"), newest ? newest.fetch("commit") : changed_in]
      end

      # Where a member no commit changed is changed now: a plugin's version installed, or else uncommitted text.
      #: () -> String
      def changed_in
        version = @member.dig("source", "version")
        version ? "version:#{version}" : "uncommitted"
      end

      # What the member was compared with, and whether its audit waits on an upgrade.
      #: () -> Array[String]
      def tail = [@member.dig("since", "baseline").to_s, *("waiting_on_an_upgrade" if @member["waiting_on_an_upgrade"])]

      #: (Array[String]) -> String
      def joined(fields) = fields.map { |field| VisibleText.new(field).to_s }.join("\t")

      # The newest commit's subject, with how many earlier commits changed the member, and whether it changed
      # again on disk.
      #: (Hash[String, untyped], Hash[String, untyped]) -> String
      def described(newest, history)
        earlier = history.fetch("commits").length - 1
        more = history.dig("stopped_at", "reason") == "limit" ? " or more" : ""
        notes = [("+#{earlier}#{more} earlier" if earlier.positive?),
                 ("also uncommitted" if history["uncommitted"])].compact
        notes.empty? ? newest.fetch("subject") : "#{newest.fetch("subject")} (#{notes.join("; ")})"
      end
    end
  end
end
