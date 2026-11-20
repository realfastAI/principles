# typed: strict
# frozen_string_literal: true

require "json"

module Principles
  # What this tool prints, built from domain values at print time. views/CLAUDE.md owns the boundary.
  module Views
    # The text this tool prints to guide the agent, kept in views/prompts/ under a folder for the
    # workflow step that uses it. views/CLAUDE.md owns the layout. A prompt is Markdown wrapped for
    # reading: single line breaks join into spaces, and a blank line separates paragraphs.
    module Prompts
      ROOT = File.join(__dir__, "prompts").freeze #: String

      # A prompt's text, with each %{name} placeholder filled from values.
      #: (String, **String) -> String
      def self.text(name, **values) = Prompt.read(name).wrapped.filled(values)

      # A prompt printed as Markdown, such as a command's --help: its lines stay as written, and each
      # %{name} placeholder is filled from values.
      #: (String, **String) -> String
      def self.markdown(name, **values) = Prompt.read(name).filled(values)

      # A prompt that shows a shape by example, as JSON data.
      #: (String) -> untyped
      def self.data(name)
        JSON.parse(File.read(File.join(ROOT, "#{name}.json")))
      end

      # Every prompt name, relative to ROOT and without its extension.
      #: () -> Array[String]
      def self.names
        Dir.glob("**/*.{md,json}", base: ROOT).map { |path| path.sub(/\.(md|json)\z/, "") }.sort
      end
    end

    # One packaged prompt: its name and its text as written. It lives beside Prompts, so the views' one
    # file-reading exception stays one file; give it its own file and spec if it grows rules of its own.
    class Prompt
      # The prompt packaged as name.md under Prompts::ROOT.
      #: (String) -> Prompt
      def self.read(name) = new(name, File.read(File.join(Prompts::ROOT, "#{name}.md")).strip)

      #: (String, String) -> void
      def initialize(name, text)
        @name = name
        @text = text
        freeze
      end

      # The prompt wrapped for reading: single line breaks join into spaces, and a blank line separates
      # paragraphs.
      #: () -> Prompt
      def wrapped
        Prompt.new(@name, @text.split(/\n{2,}/).map { |paragraph| paragraph.gsub(/\s*\n\s*/, " ") }.join("\n\n"))
      end

      # The text with each placeholder filled. Text with no values is left as it is, since a prompt may hold a
      # literal %, but one holding a placeholder is refused, so it never reaches the agent unfilled.
      #: (Hash[Symbol, String]) -> String
      def filled(values)
        return format(@text, **values) unless values.empty?

        placeholder = @text[/%\{\w+\}/]
        raise ArgumentError, "prompt #{@name} needs a value for #{placeholder}" if placeholder

        @text
      end
    end
  end
end
