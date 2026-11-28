# typed: strict
# frozen_string_literal: true

require "psych"
require_relative "outline_section"
require_relative "text_within"
require_relative "without_prose"

module Principles
  # The domain logic, and the mediation of persistence. models/CLAUDE.md owns the boundary.
  module Models
    # A CI workflow's text as its outline reads it: a section per job, headed by its id and name, its items the job's
    # steps, each by its name or else what it runs or uses. A rule a project enforces in CI is named there, and a
    # survey reading Markdown headings alone never found it. The YAML is read as nodes, which keep each job's lines
    # and leave a key such as `on` a string.
    class WorkflowJobs
      include WithoutProse

      # A GitHub Actions workflow file, the kind of text this reads.
      PATH = %r{(?:\A|/)\.github/workflows/[^/]+\.ya?ml\z}
      # What a step without a name is known by, in the order looked for.
      STEP_KEYS = %w[run uses].freeze

      #: (String) -> void
      def initialize(text)
        @text = text
        freeze
      end

      # Each job as a section, spanning the lines from its id to its last; none when the YAML does not parse, so the
      # file is listed by its path and size alone.
      #: () -> Array[OutlineSection]
      def sections
        document = Psych.parse(@text) or return []

        pairs(value(document.root, "jobs")).map do |id, job|
          OutlineSection.new(heading: heading(id.value, value(job, "name")), items: steps(value(job, "steps")),
                             first_line: id.start_line + 1, last_line: job.end_line)
        end
      rescue Psych::SyntaxError
        []
      end

      private

      #: (String, Psych::Nodes::Node?) -> String
      def heading(id, name) = name.is_a?(Psych::Nodes::Scalar) ? "job #{id}: #{name.value}" : "job #{id}"

      # Each step as an item, by its name, or else by the first line of what it runs or the action it uses, on the line
      # its step starts.
      #: (Psych::Nodes::Node?) -> Array[OutlineItem]
      def steps(sequence)
        return [] unless sequence.is_a?(Psych::Nodes::Sequence)

        sequence.children.filter_map do |step|
          text = step_text(step) or next

          OutlineItem.new("- #{TextWithin.new(text, at_most: OutlineSection::ITEM_CHARACTERS).by_words}",
                          line: step.start_line + 1)
        end
      end

      # A step by its name, or else by the first line of what it runs or the action it uses; nil with none of them.
      #: (Psych::Nodes::Node) -> String?
      def step_text(step)
        key = STEP_KEYS.find { |each| scalar(step, each) }
        scalar(step, "name") || (key && "#{key}: #{scalar(step, key).to_s.lines.first.to_s.strip}")
      end

      # The text of a mapping's scalar value under key; nil when it has none.
      #: (Psych::Nodes::Node?, String) -> String?
      def scalar(mapping, key)
        found = value(mapping, key)
        found.value if found.is_a?(Psych::Nodes::Scalar)
      end

      # A mapping's value node under key; nil when the node is no mapping or lacks the key.
      #: (Psych::Nodes::Node?, String) -> Psych::Nodes::Node?
      def value(mapping, key) = pairs(mapping).find { |found, _| found.value == key }&.last

      # A mapping's keys with their values, its keys scalars; none for any other node.
      #: (Psych::Nodes::Node?) -> Array[[Psych::Nodes::Scalar, Psych::Nodes::Node]]
      def pairs(mapping)
        return [] unless mapping.is_a?(Psych::Nodes::Mapping)

        mapping.children.each_slice(2).filter_map do |key, found|
          [key, found] if key.is_a?(Psych::Nodes::Scalar) && found
        end
      end
    end
  end
end
