# typed: strict
# frozen_string_literal: true

require_relative "../error"
require_relative "json_digest"

module Principles
  # The domain logic, which loads and saves itself through data/. models/CLAUDE.md owns the boundary.
  module Models
    # The id of a judgement request: the principle, the phase and a digest of everything the request
    # depends on, as ID.PHASE.DIGEST. This tool stores no request, so an answer is matched by recomputing
    # the digest from the project as it is now: a different digest means something the request depended
    # on has changed. The digest has no secret, so it catches mistakes, not forgery.
    class RequestId
      PHASES = %w[assessment correction acknowledgement acknowledgements repointing].freeze
      FORMAT = /\A(?<principle>[a-z0-9]+(?:-[a-z0-9]+)*)\.(?<phase>[a-z]+)\.(?<digest>[0-9a-f]{12})\z/

      #: String
      attr_reader :principle_id
      #: String
      attr_reader :phase

      # The id of a request in phase for principle_id, which depends on parts, digested by what they say, so an answer
      # whose keys are reordered, as `jq -S` does, still matches.
      #: (principle_id: String, phase: String, parts: Array[untyped]) -> RequestId
      def self.for(principle_id:, phase:, parts:)
        new(principle_id, phase, JsonDigest.new([principle_id, phase, *parts]).to_s[0, 12].to_s)
      end

      # The id of a request whose answer hands part of it back: its digest's first half digests what is handed back
      # alone and its second the parts this tool recomputes, so an answer that edited what it hands back is told apart
      # from a project that changed.
      #: (principle_id: String, phase: String, handed: untyped, parts: Array[untyped]) -> RequestId
      def self.handing_back(principle_id:, phase:, handed:, parts:)
        half = ->(digested) { JsonDigest.new([principle_id, phase, digested]).to_s[0, 6].to_s }
        new(principle_id, phase, half.call(handed) + half.call(parts))
      end

      # What every id of a request in phase for principle_id starts with, before its digest.
      #: (principle_id: String, phase: String) -> String
      def self.prefix(principle_id:, phase:) = "#{principle_id}.#{phase}."

      # An id as an agent passed it, refused unless it has the shape this tool prints.
      #: (String) -> RequestId
      def self.parse(text)
        match = FORMAT.match(text)
        unless match && PHASES.include?(match[:phase])
          raise Error.new("unknown_request", "#{text} does not have the form of a request id",
                          "Use the request_id of the latest start-audit or submit-answer result.")
        end

        new(match[:principle].to_s, match[:phase].to_s, match[:digest].to_s)
      end

      #: (String, String, String) -> void
      def initialize(principle_id, phase, digest)
        @principle_id = principle_id
        @phase = phase
        @digest = digest
        freeze
      end

      # Refuses answer unless it is an object whose request_id is this id.
      #: (untyped) -> void
      def check_answer(answer)
        return if answer.is_a?(Hash) && answer["request_id"] == to_s

        raise Error.new("request_mismatch", "answer.request_id must equal #{self}", "Start from #{answer_to_fill}.")
      end

      # Where the answer to fill this request is printed, as a repair names it: a correction request prints none, since
      # show-open-correction prints it alone; every other request prints it as its response_template.
      #: () -> String
      def answer_to_fill
        return "the response_template of this request" unless @phase == "correction"

        "the answer show-open-correction #{@principle_id} prints"
      end

      # What of a handing_back id differs in other: :handed, what the answer hands back, before :parts, what this tool
      # recomputes, or nil when neither does.
      #: (RequestId) -> Symbol?
      def differs_from(other)
        mine = to_s
        theirs = other.to_s
        return :handed unless mine[0...-6] == theirs[0...-6]

        :parts unless mine == theirs
      end

      #: () -> String
      def to_s
        "#{RequestId.prefix(principle_id: @principle_id, phase: @phase)}#{@digest}"
      end

      #: (untyped) -> bool
      def ==(other)
        other.is_a?(RequestId) ? other.to_s == to_s : false
      end
    end
  end
end
