# typed: strict
# frozen_string_literal: true

require_relative "../error"
require_relative "../data/project_files"

module Principles
  # The domain logic, and the mediation of persistence. models/CLAUDE.md owns the boundary.
  module Models
    # One root entry file as the project holds it: the path, the file its links lead to, and its text, or the code
    # this tool refused it with when it cannot be read. It says whether it links the other entry file: as a symbolic
    # link to it, or by an import word, @AGENTS.md or @CLAUDE.md, which Claude Code documents as loading the file it
    # names. That is a fact about the string; a plain mention of the other's name is not a link, and an unread text
    # shows no import. It says, too, when git does not track it, since such a file may be the owner's alone.
    class EntryFile
      # The entry file at path as the project holds it, or nil when there is none; tracked says whether git tracks
      # it, and is true outside git, where nothing is checked.
      #: (Data::ProjectFiles, String, tracked: bool) -> EntryFile?
      def self.read(files, path, tracked:)
        return nil unless files.file?(path)

        leads_to = files.leads_to(path)
        begin
          new(path, leads_to: leads_to, text: files.read_text(path), tracked: tracked)
        rescue Error => e
          new(path, leads_to: leads_to, not_read: e.payload.fetch("code"), tracked: tracked)
        end
      end

      #: (String, leads_to: String, ?text: String?, ?not_read: String?, ?tracked: bool) -> void
      def initialize(path, leads_to:, text: nil, not_read: nil, tracked: true)
        @path = path
        @leads_to = leads_to
        @text = text
        @not_read = not_read
        @tracked = tracked
        freeze
      end

      # What setup reports of the file: that it exists, that git does not track it when it does not, why its text
      # could not be read when it could not, and how it links other, when it does.
      #: (String) -> Hash[String, untyped]
      def facts(other)
        untracked = @tracked ? {} : { "tracked" => false }
        unread = @not_read ? { "not_read" => @not_read } : {}
        { "path" => @path, "exists" => true, **untracked, **unread }.merge(link(other))
      end

      private

      # How this file links other, or nothing when it does not.
      #: (String) -> Hash[String, String]
      def link(other)
        return { "links_to" => other, "by" => "symbolic_link" } if @leads_to == other
        return { "links_to" => other, "by" => "import" } if @text.to_s.match?(import_word(other))

        {}
      end

      # An @ import of path, as one word of the text.
      #: (String) -> Regexp
      def import_word(path) = %r{(?:\A|\s)@(?:\./)?#{Regexp.escape(path)}(?=\s|\z)}
    end
  end
end
