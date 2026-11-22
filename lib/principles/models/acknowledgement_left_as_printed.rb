# typed: strict
# frozen_string_literal: true

require_relative "acknowledgements"
require_relative "left_as_printed"
require_relative "refusal_before_shape"
require_relative "template_placeholders"

module Principles
  # The domain logic, and the mediation of persistence. models/CLAUDE.md owns the boundary.
  module Models
    # The fields a one-member audit's answer leaves as its template printed them, refused in one refusal before the
    # answer's shape: its judgement's, meaning_kept and reason, and a checked member's exit_status, which was
    # otherwise refused as text with a repair offering the not_run_reason this template refuses. It holds the
    # placeholders the template prints in each; AcknowledgementPlaceholders::LEFT_AS_PRINTED is the one every
    # acknowledgement uses.
    class AcknowledgementLeftAsPrinted
      include RefusalBeforeShape

      # The field, named as a refusal names it, where a checked member's answer reports its exit status.
      EXIT_STATUS = "check_result.exit_status" #: String

      # judged holds the placeholders of the judgement's fields, exit_status the one printed where the status goes;
      # they are read in each entry of the answer's members, keyed by member id, for one member as for several.
      #: (TemplatePlaceholders, exit_status: String) -> void
      def initialize(judged, exit_status:)
        @judged = judged
        @exit_status = exit_status
        freeze
      end

      # @override
      #: (untyped, String, Array[Hash[String, String]]) -> void
      def refuse_in(answer, _source, shape_problems)
        return unless answer.is_a?(Hash)

        LeftAsPrinted.new(pointers_in(answer)).refuse(besides: shape_problems)
      end

      private

      # Each field left as printed in each entry of the answer's members, by name, beside its pointer.
      #: (Hash[String, untyped]) -> Hash[String, String]
      def pointers_in(answer)
        members = answer["members"]
        return {} unless members.is_a?(Hash)

        members.select { |_id, entry| entry.is_a?(Hash) }.flat_map do |id, entry|
          left_in(entry).map { ["#{id} #{it}", "#{Acknowledgements.entry_pointer(id)}/#{it.tr(".", "/")}"] }
        end.to_h
      end

      # Each field answer leaves as printed, by name.
      #: (Hash[String, untyped]) -> Array[String]
      def left_in(answer)
        judged = @judged.to_h.keys.select { @judged.left?(it, answer[it]) }
        status_left?(answer["check_result"]) ? [*judged, EXIT_STATUS] : judged
      end

      # Whether check_result's exit_status is the placeholder the template prints there.
      #: (untyped) -> bool
      def status_left?(check_result) = check_result.is_a?(Hash) && check_result["exit_status"] == @exit_status
    end
  end
end
