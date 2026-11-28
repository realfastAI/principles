# typed: strict
# frozen_string_literal: true

module Principles
  # The domain logic, and the mediation of persistence. models/CLAUDE.md owns the boundary.
  module Models
    # A member's text as a host sends it. A host lists a skill by its frontmatter description's value, on one line
    # after the skill's name, so a frontmatter field is that value alone: without its key, a block scalar's indicator
    # or the quotes round it. Its lines are matched one by one, stripped, so a folded value's lines still match the
    # one line the host joins them into.
    class MemberTextAsSent
      # The text of the member locator finds in project, a field when locator queries one.
      #: (Project, Locator) -> MemberTextAsSent
      def self.of(project, locator) = new(project.member_text(locator), field: !locator.query.nil?)

      #: (String, field: bool) -> void
      def initialize(text, field:)
        @text = text
        @field = field
        freeze
      end

      #: () -> String
      def to_s
        return @text unless @field

        @text.sub(/\A[\w-]+:[ \t]*(?:[>|][-+]?[ \t]*\n)?/, "").sub(/\A(["'])(.*)\1\s*\z/m, '\2')
      end
    end
  end
end
