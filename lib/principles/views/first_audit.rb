# typed: strict
# frozen_string_literal: true

require_relative "invocation"
require_relative "prompts"

module Principles
  # What this tool prints, from plain values a controller hands it. views/CLAUDE.md owns the boundary.
  module Views
    # The first full audit's place after mapping: a commit can supply the members' baseline in git, while the
    # keeping principle also needs an own principle whose keeping it can judge.
    class FirstAudit
      #: (Invocation, in_git: bool) -> void
      def initialize(invocation, in_git:)
        @invocation = invocation
        @in_git = in_git
        freeze
      end

      # The step after adding members, since the next add-member remains the command to answer with.
      #: (String, ?keeps_held: Array[String]?) -> String
      def after_mapping(id, keeps_held: nil)
        return after_keeping_mapping(id, keeps_held) if keeps_held

        if @in_git
          return "When the map lists every member, commit it: list-member-problems then reports any change to a " \
                 "member since that commit. Only a full audit judges whether they reinforce the principle.\n" \
                 "To start it when you choose: #{start_audit(id)}"
        end

        "When the map lists every member, start the audit. It judges whether they reinforce the principle, and " \
          "gives each member the baseline list-member-problems compares it with.\nTo start it: #{start_audit(id)}"
      end

      # The keeping audit waits until there is a project's own principle for it to keep held.
      #: (String, existing_principles: Array[Hash[String, untyped]]) -> String
      def keeping(id, existing_principles:)
        if existing_principles.empty?
          return "This principle's first full audit judges whether the keeping works, so leave it until one of the " \
                 "project's own principles is mapped.\n" \
                 "To find the first of them: #{@invocation.in_project("list-candidate-files")}"
        end

        keeping_audit(id, principles: "the principles under existing_principles")
      end

      private

      # The keeping audit, for the principles it keeps held, as the command that printed them names them.
      #: (String, principles: String) -> String
      def keeping_audit(id, principles:)
        "This principle's first full audit judges whether the keeping works for #{principles}.\n" \
          "To start it: #{start_audit(id)}"
      end

      # Adding the keeping passage retains setup's first-own-principle prerequisite while it holds none.
      #: (String, Array[String]) -> String
      def after_keeping_mapping(id, keeps_held)
        if keeps_held.any?
          return "#{keeping_baseline}\n#{keeping_audit(id, principles: "the principles list-principles lists")}"
        end

        Prompts.text("set-principles-up/first-keeping-audit-after-own-principle",
                     baseline: keeping_baseline,
                     find: @invocation.in_project("list-candidate-files"),
                     audit: start_audit(id))
      end

      # What gives the keeping map's members their baseline until its first full audit.
      #: () -> String
      def keeping_baseline
        if @in_git
          "When the map lists every member, commit it: that commit is the members' baseline until an audit."
        else
          "Outside git, the first full audit gives each member its baseline."
        end
      end

      #: (String) -> String
      def start_audit(id)
        @invocation.in_project("start-audit", id)
      end
    end
  end
end
