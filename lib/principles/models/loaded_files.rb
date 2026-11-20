# typed: strict
# frozen_string_literal: true

require_relative "member_loads"

module Principles
  # The domain logic, and the mediation of persistence. models/CLAUDE.md owns the boundary.
  module Models
    # The files a principle's members load, each once however many of its members it holds, since every member's loads
    # gives its whole file's size and summing members counts a shared file once per member. Only session start loads
    # its files together, so only those are totalled; a file that loads on files, on invocation or on delegation loads
    # apart from the rest. A file that cannot be read has no size and is not totalled.
    class LoadedFiles
      # The files members load, each read whole once, as files hold it.
      #: (Data::ProjectFiles, PrincipleMembers, hooks: HookCommands) -> LoadedFiles
      def self.read(files, members, hooks:)
        new(members.paths.to_h { |path| [path, MemberLoads.of_file(files, path, hooks: hooks)] })
      end

      # loads holds each file's whole-file MemberLoads by path.
      #: (Hash[String, MemberLoads]) -> void
      def initialize(loads)
        @loads = loads.select { |_path, file| file.carried? } #: Hash[String, MemberLoads]
        freeze
      end

      # The aggregate's derivation basis, files_loaded and session_start_total, empty lists/totals omitted.
      #: () -> Hash[String, untyped]
      def to_h
        return {} if @loads.empty?

        total = session_start_total
        { "loading_basis" => MemberLoads::BASIS.dup,
          "files_loaded" => @loads.map { |path, file| { "path" => path }.merge(file.claude_code) },
          **(total ? { "session_start_total" => total } : {}) }
      end

      private

      # The files that load whole at session start and their summed size, beside the descriptions that load at start
      # while their bodies wait; each left out when there is none, and nil when there is neither.
      #: () -> Hash[String, untyped]?
      def session_start_total
        files = summed(@loads.values.select(&:at_session_start?).map(&:size), "files", MemberLoads::FILE_SIZE_FIELDS)
        descriptions = summed(@loads.values.map(&:description_at_start), "count", MemberLoads::DESCRIPTION_SIZE_FIELDS)
        total = files.merge(descriptions.empty? ? {} : { "descriptions" => descriptions })
        total unless total.empty?
      end

      # How many of sizes were measured, under counted, and their sum under each of fields; empty when none was.
      #: (Array[Hash[String, Integer]], String, [String, String]) -> Hash[String, Integer]
      def summed(sizes, counted, fields)
        measured = sizes.reject(&:empty?)
        return {} if measured.empty?

        { counted => measured.size }.merge(fields.to_h { |field| [field, measured.sum { it.fetch(field) }] })
      end
    end
  end
end
