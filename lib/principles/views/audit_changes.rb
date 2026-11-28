# typed: strict
# frozen_string_literal: true

require_relative "audit_commit"
require_relative "landed_since_base"
require_relative "members_changed_during_audit"
require_relative "principle_with_changed_members"
require_relative "shell_word"

module Principles
  # What this tool prints, from plain values a controller hands it. views/CLAUDE.md owns the boundary.
  module Views
    # What a completed audit changed in the project, as its result prints it: the files to commit, in git what
    # landed since the base commit, as LandedSinceBase prints it, each other principle whose members its fixes changed,
    # each file the record cites that no longer exists, and the audited principle's members that changed during the
    # audit, as MembersChangedDuringAudit prints them.
    class AuditChanges
      #: (files_to_commit: Array[String], ?landed: LandedSinceBase?,
      #|  ?other_changed: Array[PrincipleWithChangedMembers], ?cited_files_missing: Array[String],
      #|  ?members_changed: MembersChangedDuringAudit) -> void
      def initialize(files_to_commit:, landed: nil, other_changed: [], cited_files_missing: [],
                     members_changed: MembersChangedDuringAudit.new)
        @files_to_commit = files_to_commit
        @members_changed = members_changed
        @landed = landed
        @other_changed = other_changed
        @cited_files_missing = cited_files_missing
        freeze
      end

      # The files to commit, and each other principle whose members the audit's fixes changed, as the next step
      # names them.
      #: Array[String]
      attr_reader :files_to_commit
      #: Array[PrincipleWithChangedMembers]
      attr_reader :other_changed

      # The audited principle's members that changed during the audit, which the next step asks to audit again.
      #: MembersChangedDuringAudit
      attr_reader :members_changed

      # The fields as printed; the members changed during the audit and the cited files missing, what landed since
      # the base only in git, where it is given, and the other principles, each only when there are some.
      #: () -> Hash[String, untyped]
      def to_h
        printed = { "files_to_commit" => @files_to_commit } #: Hash[String, untyped]
        printed = printed.merge(@members_changed.to_h)
        printed = printed.merge("cited_files_missing" => @cited_files_missing) unless @cited_files_missing.empty?
        printed = printed.merge(@landed.to_h) if @landed
        others = @other_changed.map(&:to_h)
        others.empty? ? printed : printed.merge("other_principles_with_changed_members" => others)
      end

      # Refuses, staging nothing, while a merge is unfinished, whose commit would otherwise take in these files
      # (758f12b), saying why on stderr, the one place the stop is explained. It fails with false, not
      # exit, so a shell running it outside the printed subshell survives; the braces keep a failed cd from reading
      # as a merge. The message is in single quotes, so it holds no apostrophe.
      NO_MERGE_UNFINISHED = '{ test ! -e "$(git rev-parse --git-path MERGE_HEAD)" || ' \
                            "{ echo 'principles: a merge is unfinished; finish or abort it, then run this again' " \
                            ">&2; false; }; }" #: String

      # In git, the command that commits the files to commit and nothing else staged, with subject, run from
      # project, where those paths are relative. Each path is quoted for the shell and read by git as written, since
      # project files anyone may have written name them. nil outside git, where it could not run.
      #: (String, String) -> String?
      def commit_with(subject, project)
        return unless @landed

        files = @files_to_commit.map { |file| ShellWord.new(file) }.join(" ")
        "(cd #{ShellWord.new(project)} && #{NO_MERGE_UNFINISHED} && git --literal-pathspecs add -- #{files} && " \
          "git --literal-pathspecs commit -m #{ShellWord.new(subject)} -- #{files})"
      end

      # How the result says to commit these files with subject, run from project: in git with commit_with's
      # command, outside git by hand.
      #: (String, String) -> (AuditCommit | AuditCommit::ByHand)
      def commit(subject, project)
        command = commit_with(subject, project)
        return AuditCommit::ByHand.new(@files_to_commit) unless command

        AuditCommit.new(files_to_commit: @files_to_commit, subject:, command:)
      end
    end
  end
end
