# typed: strict
# frozen_string_literal: true

module Principles
  module Models
    # Literal loading-scope qualifiers for mapping feedback, distinct from persisted LoadingFacts.
    class LoadingScope
      QUALIFIERS = %w[
        when context invoked_by skill_part description files paths_field
      ].freeze #: [String, String, String, String, String, String, String]
      KNOWN_MOMENTS = %w[session_start on_files on_invocation on_delegation not_loaded].freeze #: Array[String]

      # fields is MemberLoads#claude_code's derivation, not frontmatter or a second host classifier.
      #: (Hash[String, untyped]) -> void
      def initialize(fields)
        @facts = projected(fields) #: Hash[String, untyped]
        freeze
      end

      #: () -> Hash[String, untyped]
      def to_h = @facts

      #: () -> bool
      def known? = known_in?(@facts)

      #: (untyped) -> bool
      def ==(other) = other.is_a?(LoadingScope) && @facts.eql?(other.to_h)

      alias eql? ==

      #: () -> Integer
      def hash = @facts.hash

      private

      # Unknown markers survive for limitations, but are never compared as known scopes.
      #: (Hash[String, untyped]) -> bool
      def known_in?(fields)
        KNOWN_MOMENTS.include?(fields["when"]) && (!fields["description"] || known_in?(fields["description"]))
      end

      #: (Hash[String, untyped]) -> Hash[String, untyped]
      def projected(fields)
        facts = fields.slice(*QUALIFIERS).transform_values { |value| owned(value) }
        facts["description"] = projected(fields.fetch("description")) if fields["description"]
        facts.freeze
      end

      # Copy literal qualifiers without normalizing their strings or array order; hash keys must stay stable.
      #: (untyped) -> untyped
      def owned(value)
        case value
        when Hash then value.transform_values { |each| owned(each) }.freeze
        when Array then value.map { |each| owned(each) }.freeze
        when String then value.dup.freeze
        else value
        end
      end
    end
  end
end
