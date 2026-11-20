# typed: strict
# frozen_string_literal: true

require_relative "invocation"
require_relative "problem_lines"
require_relative "visible_text"

module Principles
  # What this tool prints, from plain values a controller hands it. views/CLAUDE.md owns the boundary.
  module Views
    # list-open-findings' result: each finding the last completed audit of a principle deferred or accepted, what that
    # covers, and what to do next.
    class FindingsResult
      SCOPE = "Each principle's last completed audit only, as .principles/audits/ID.json holds it. The next full " \
              "audit decides each: one that still holds stays in the record, and one it closes is then only in git: " \
              "git log -p -- .principles/audits/ID.json shows it."

      NONE_OPEN = "No finding is deferred or accepted in the last completed audit of any principle listed."

      #: (Invocation) -> void
      def initialize(invocation)
        @invocation = invocation
        freeze
      end

      # findings holds each deferred or accepted finding, with its principle and action.
      #: (Array[Hash[String, untyped]]) -> Hash[String, untyped]
      def open(findings)
        { "findings" => findings, "scope" => SCOPE, "next_action" => next_action(findings) }
      end

      # list-open-findings --lines: each finding on a line, its principle, id, whom it waits on and the whole days it
      # has been open, so the agent can see which to raise, and how long each has waited, without a script over the
      # list. Free text is escaped, and its line breaks read as spaces, so each finding stays on its
      # own line. findings holds each one's principle, finding_id, action, days_open and any waits_on.
      #: (Array[Hash[String, untyped]]) -> Lines
      def lines(findings)
        text = findings.map { |finding| "#{line(finding)}\n" }.join
        Lines.new(stdout: findings.empty? ? "#{NONE_OPEN}\n" : text, stderr: "", status: 0)
      end

      # One finding as list-principles --open-findings lists it in its principle's row: its id, whom it waits on and
      # the whole days it has been open, as --lines words them.
      #: (Hash[String, untyped]) -> String
      def summary(finding)
        "#{one_line(finding.fetch("finding_id"))} #{waited_on(finding)}; #{days_open(finding)}"
      end

      private

      #: (Hash[String, untyped]) -> String
      def line(finding)
        "#{finding.fetch("principle")}\t#{one_line(finding.fetch("finding_id"))}\t#{waited_on(finding)}\t" \
          "#{days_open(finding)}"
      end

      #: (Hash[String, untyped]) -> String
      def days_open(finding)
        days = finding.fetch("days_open")
        "open #{days} day#{"s" unless days == 1}"
      end

      # Whom finding waits on, or that it is accepted, and so by design waits on no one.
      #: (Hash[String, untyped]) -> String
      def waited_on(finding)
        return "accepted" if finding["action"] == "accepted"

        waits_on = finding["waits_on"]
        waits_on ? "waits on: #{one_line(waits_on)}" : "waits on no one named"
      end

      #: (String) -> String
      def one_line(text) = VisibleText.new(text.gsub(/\s+/, " ")).to_s

      #: (Array[Hash[String, untyped]]) -> String
      def next_action(findings)
        return NONE_OPEN if findings.empty?

        audits = findings.map { |finding| finding.fetch("principle") }.uniq.map do |id|
          @invocation.in_project("start-audit", id)
        end
        "Read each finding where its recorded_at points; null means it was never written up. A deferral's waits_on " \
          "is whom it was asked to wait on, to decide what, as of waits_on_since: check that it still holds before " \
          "chasing it. Its principle's next full audit asks you to decide each one:\n#{audits.join("\n")}"
      end
    end
  end
end
