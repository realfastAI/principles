# typed: strict
# frozen_string_literal: true

require_relative "../error"
require_relative "../prose_list"
require_relative "answer_fields"
require_relative "disposition"

module Principles
  # The domain logic, and the mediation of persistence. models/CLAUDE.md owns the boundary.
  module Models
    # An agent's answer to a correction request: one disposition for each finding the assessment raised, each
    # checked as a Disposition, and no member changed that no fix claims. The block locates each piece of
    # evidence, and where a finding is recorded, in the project. samples is the answer guide's disposition for
    # each action, whose text no field may give back unchanged.
    class CorrectionAnswer
      #: (untyped, Array[untyped], samples: Hash[String, untyped]) { (Locator) -> void } -> void
      def initialize(response, findings, samples:, &locate)
        @response = response
        @samples = samples
        @finding_ids = findings.map { |finding| finding.fetch("id") } #: Array[untyped]
        @fields = AnswerFields.new(locate) #: AnswerFields
      end

      # The dispositions, once each is checked against changed, the members that changed since the audit began, as
      # AuditStart#changed names them, those added included (T69).
      #: (changed: Array[String]) -> Array[Disposition]
      def dispositions(changed:)
        dispositions = one_per_finding
        unclaimed = changed - dispositions.flat_map { |disposition| disposition.claimed_members(changed) }
        return dispositions if unclaimed.empty?

        raise Error.new("unassessed_changes", "Other members changed: #{unclaimed.join(", ")}",
                        "Start a fresh audit, or include their reassessment in a fixed disposition.")
      end

      private

      #: () -> Array[Disposition]
      def one_per_finding
        given = @fields.array(@response["dispositions"], "dispositions")
        dispositions = given.each_with_index.map do |disposition, index|
          Disposition.new(disposition, @fields, at: "/dispositions/#{index}", samples: @samples)
        end
        unless dispositions.map(&:finding_id).sort == @finding_ids.sort
          raise Error.new("incomplete_dispositions",
                          "Dispose of each finding exactly once: #{@finding_ids.join(", ")}", "Complete dispositions.")
        end

        refuse_unfinished(dispositions)
        dispositions
      end

      # Refuses every field the dispositions leave empty, as the template's placeholder or as the answer guide's
      # sample in one refusal, so a copied template takes one repair, not one submit per field.
      #: (Array[Disposition]) -> void
      def refuse_unfinished(dispositions)
        unfinished = dispositions.flat_map(&:unfinished)
        return if unfinished.empty?

        raise Error.new("invalid_disposition", "Still to write: #{ProseList.new(unfinished.map(&:to_s))}",
                        unfinished.map(&:repair).uniq.join(" "), fields: unfinished.map(&:field))
      end
    end
  end
end
