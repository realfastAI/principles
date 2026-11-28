# typed: strict
# frozen_string_literal: true

require "json"
require "tempfile"
require_relative "ran"

module Principles
  # Every file and process this tool reads or writes. data/CLAUDE.md owns the boundary.
  module Data
    # The request files that may hold one of some patterns, found by one rg run over the files as the host wrote them,
    # so only those are decoded. The JSON writers of the hosts it captures, Node's among them, and jq and Ruby's, agree
    # on writing a quote, a backslash and a control character, and differ on a slash, a DEL and a non-ASCII character,
    # each written raw or as an escape, so each pattern is looked for in every one of those forms. A writer escaping
    # < > & as Go's HTML-safe form does is not covered.
    class RawRequestFilter
      # rg's options for listing each file holding a fixed string, one a line, ignore files left unread, since git
      # ignores the folder the requests are in.
      SEARCH = %w[--no-config --no-ignore -F -l].freeze #: Array[String]
      # A character outside ASCII, which a writer may write as itself or as \u escapes, in either case of hex digit.
      NON_ASCII = /[^\x00-\x7f]/

      # Each of files, in the requests folder, that may hold one of patterns, none of them empty, and whether rg read
      # every file, finding one or none, and wrote no error.
      #: (String, Array[String], Array[String]) -> [Array[String], bool]
      def self.listing(requests, files, patterns)
        Tempfile.create("principles-raw-patterns") do |listed|
          listed.write(patterns.flat_map { written_forms(it) }.uniq.join("\n"))
          listed.flush
          search = ["rg", *SEARCH, "-f", listed.path]
          Tempfile.create("principles-raw-errors") { listed_by(requests, search, files, it) }
        end
      end

      # Each of files the command lists, run with them in the requests folder, and whether it found one or none and
      # wrote no error to errors.
      #: (String, Array[String], Array[String], File) -> [Array[String], bool]
      def self.listed_by(requests, command, files, errors)
        printed, status = Ran.run([*command, "--", *files], requests, errors.path)
        [files & printed.split("\n"), [0, 1].include?(status) && File.empty?(errors.path)]
      end

      # Each form a JSON writer may write pattern in inside a string.
      #: (String) -> Array[String]
      def self.written_forms(pattern)
        [JSON.generate(pattern)[1..-2].to_s]
          .flat_map { [it, it.gsub("/", "\\/")] }
          .flat_map { [it, it.gsub("\u007f", "\\u007f")] }
          .flat_map { |form| [form, *%w[%04x %04X].map { |hex| form.gsub(NON_ASCII) { escaped(it, hex) } }] }
          .uniq
      end

      # character as \u escapes, a surrogate pair beyond the first plane, with hex digits as hex writes them.
      #: (String, String) -> String
      def self.escaped(character, hex)
        character.encode("UTF-16BE").unpack("n*").map { "\\u#{format(hex, it)}" }.join
      end
      private_class_method :listed_by, :written_forms, :escaped
    end
  end
end
