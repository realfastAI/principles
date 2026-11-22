# typed: strict
# frozen_string_literal: true

require_relative "../data/project_files"
require_relative "../data/project_root"
require_relative "../data/map_files"
require_relative "../data/audit_files"
require_relative "../data/principles_subfolder"
require_relative "../data/repository"
require_relative "candidate_inventory"
require_relative "entry_files"
require_relative "member"
require_relative "member_file"
require_relative "hook_commands"
require_relative "loaded_files"
require_relative "located_text"
require_relative "member_loads"
require_relative "member_lines"
require_relative "mapped_principles"
require_relative "member_snapshots"
require_relative "missing_files"
require_relative "locate_refusal"
require_relative "audit_records"
require_relative "project_history"
require_relative "principle_history"
require_relative "principles_folder_move"
require_relative "sent_answer"
require_relative "guidance_search_paths"
require_relative "survey_search_paths"

module Principles
  # The domain logic, and the mediation of persistence. models/CLAUDE.md owns the boundary.
  module Models
    # The user's project as this tool reads it: its instruction files, each member's text, the answers an
    # agent hands in, and the maps, audit records and git history kept beside them. Controllers reach the
    # project only through this model. It is handed its five data adapters, so a spec can hand it stand-ins
    # that meet the same contracts.
    class Project
      # An implicit invocation reuses its nearest established project; an explicit root uses .at directly.
      #: (String) -> Project
      def self.containing(directory) = at(Data::ProjectRoot.new(directory).path)

      # The project at root, with its maps, audit records and history.
      #: (String) -> Project
      def self.at(root)
        files = Data::ProjectFiles.new(root)
        new(files: files, maps: Data::MapFiles.new(Data::PrinciplesSubfolder.new(files.root, "maps")),
            audits: Data::AuditFiles.new(Data::PrinciplesSubfolder.new(files.root, "audits")),
            repository: Data::Repository.new(files.root),
            guidance_search_paths: Data::GuidanceSearchPathsFile.new(Data::PrinciplesDirectory.new(files.root)))
      end

      #: (files: Data::ProjectFiles, maps: Data::MapFiles, audits: Data::AuditFiles,
      #|  repository: Data::Repository, guidance_search_paths: Data::GuidanceSearchPathsFile) -> void
      def initialize(files:, maps:, audits:, repository:, guidance_search_paths:)
        @files = files
        @maps = maps
        @audits = audits
        @repository = repository
        @guidance_search_paths = guidance_search_paths
        @history = nil #: ProjectHistory?
        @principle_histories = {} #: Hash[[String, PrincipleMappingHistory?], PrincipleHistory]
      end

      # The project's root, resolved.
      #: () -> String
      def root
        @files.root
      end

      #: () -> MappedPrinciples
      def principles
        refuse_unmoved_folder
        MappedPrinciples.new(@maps, history)
      end

      #: () -> AuditRecords
      def audit_records
        refuse_unmoved_folder
        AuditRecords.new(@audits, history)
      end

      #: () -> GuidanceSearchPaths
      def guidance_search_paths
        refuse_unmoved_folder
        GuidanceSearchPaths.read(@guidance_search_paths)
      end

      # The user name git commits as here, or nil when none is set, which the session-start line states as a fact.
      #: () -> String?
      def git_user_name = @repository.user_name

      # The project's history, one for the whole command, so every read names the HEAD it first read.
      #: () -> ProjectHistory
      def history
        @history ||= ProjectHistory.new(@repository, @files)
      end

      # Each principle's history view belongs to this command, sharing its captured project history.
      #: (String, ?mapping: PrincipleMappingHistory?) -> PrincipleHistory
      def principle_history(id, mapping: nil)
        key = [id.dup.freeze, mapping].freeze #: [String, PrincipleMappingHistory?]
        @principle_histories[key] ||= PrincipleHistory.new(id: key.first, history: history,
                                                           principles: principles, mapping: mapping)
      end

      # Whether two paths name one file, as their symbolic links lead them, so an edit through either is an edit
      # to both.
      #: (String, String) -> bool
      def same_file?(path, other) = @files.leads_to(path) == @files.leads_to(other)

      # Whether path names a folder in the project.
      #: (String) -> bool
      def folder?(path) = @files.folder?(path)

      # Check the location an add or move is about to persist, with the authoring-only ending constraint.
      #: (Locator) -> LocatedText
      def locate_for_authoring(locator) = member_file(locator.path).locate_for_authoring(locator)

      # The last line of the paragraph or list item a passage named by its opening alone maps only the first line
      # of, as its file type finds it; nil when none runs on.
      #: (Locator) -> Integer?
      def continues_to(locator) = member_file(locator.path).continues_to(locator)

      # The lines locator finds now, as one text; refused as located_text refuses.
      #: (Locator) -> String
      def member_text(locator) = member_file(locator.path).lines_of(locator).join

      # The text locator finds now, as one value: its path, its lines and the hash of what it says.
      #: (Locator) -> LocatedText
      def located_text(locator) = member_file(locator.path).locate(locator)

      # The member at locator, its lines in its file at commit beside its lines now, which an audit shows the
      # agent so it judges the member's own change without the rest of its file's; nil when commit lacks the
      # file or its locator finds nothing there, as after a move, which each caller says in its own terms.
      # then_locator places it at commit where it was elsewhere then, as before a move.
      #: (Locator, since: String, ?then_locator: Locator) -> MemberLines?
      def member_lines(locator, since:, then_locator: locator)
        before = history.at(since).lines(then_locator) or return nil

        MemberLines.new(at_baseline: before, now: member_file(locator.path).lines_of(locator))
      end

      # As member_lines, since the last full audit's commit, or that it cannot be found there, so a full audit still
      # starts.
      #: (Locator, since: String) -> (MemberLines | MemberLinesNotFoundAtLastAudit)
      def member_lines_since_last_audit(locator, since:)
        member_lines(locator, since: since) || MemberLinesNotFoundAtLastAudit.new
      end

      # The project file at path as the type that finds a member in it, refused when it cannot be read, or while git
      # tracks it only in another case.
      #: (String) -> MemberFile
      def member_file(path)
        MemberFile.for(path: history.tracked_paths.spelt_as_tracked(path), text: @files.read_text(path))
      end

      # Each of map's members by id, where it is in its file now and the hash of what it says there. It is
      # refused once, listing every member that cannot be found or read, so the agent repairs them together.
      #: (Principle) -> MemberSnapshots
      def snapshots(map) = MemberSnapshots.read(self, map)

      # The superseded, git-ignored file where an older version kept audit runs; this version never reads it.
      OLDER_STATE = ".memeplex/state.json" #: String

      # The files beside the maps that an older version wrote and this one does not read, so an audit kept
      # only there is no baseline.
      #: () -> Array[String]
      def unread_older_files
        @files.file?(OLDER_STATE) ? [OLDER_STATE] : []
      end

      # Each member's hash now by key, or the refusal that says why its text cannot be found or read.
      #: (PrincipleMembers) -> Hash[String, untyped]
      def current_by_key(members)
        members.to_h do |member|
          [member.key, located_text(member.locator).sha256]
        rescue Error => e
          [member.key, e.payload]
        end
      end

      #: (String, Array[Hash[String, untyped]]) -> bot
      def refuse_broken(map_id, broken)
        ids = broken.map { |member| member.fetch("id") }.join(", ")
        missing = MissingFiles.new(broken, principle: map_id, history: history)
        raise missing.refusal("#{broken.length} of #{map_id}'s members cannot be found or read: #{ids}")
      end

      # A member's text now and how fresh it is, which the block says from its hash. A member whose place
      # in its file is gone is locator_lost; one whose file cannot be read is unavailable. Both keep the
      # refusal.
      #: (Locator) { (String) -> String } -> Hash[String, untyped]
      def freshness(locator, &)
        now = located_text(locator)
        { "snapshot" => now.to_h, "freshness" => yield(now.sha256) }
      rescue Error => e
        { "freshness" => LocateRefusal.new(e.payload).member_state, "error" => e.payload }
      end

      # Each member's MemberLoads by id: when each host loads it into context, with the size of what loads, and
      # the project hooks whose commands name its file, read once for them all unless the caller already read them.
      #: (PrincipleMembers, ?HookCommands) -> Hash[String, MemberLoads]
      def member_loads(members, hooks = hook_commands)
        members.to_h { |member| [member.id, MemberLoads.read(@files, member.locator, hooks: hooks)] }
      end

      # The files members load, each read whole once, with the project's hooks as hooks read them.
      #: (PrincipleMembers, HookCommands) -> LoadedFiles
      def loaded_files(members, hooks) = LoadedFiles.read(@files, members, hooks: hooks)

      # The command hooks in each of paths present, the project settings files unless others are given.
      #: (?Array[String]) -> HookCommands
      def hook_commands(paths = HookCommands::SETTINGS) = HookCommands.read(@files, paths)

      # The root entry files every session of a host loads, whether one links the other and which git does not
      # track.
      #: () -> EntryFiles
      def entry_files = EntryFiles.read(@files, history)

      # An answer to the request given, or to the one it names when none is, from file, where - means it was
      # read from stdin, its head checked against that request's phase's answer schema and the rest left to
      # check once its request is known.
      #: (String, stdin: String?, given: String?) -> SentAnswer
      def answer(file, stdin:, given:) = SentAnswer.read(@files, file, stdin:, given:)

      # What list-candidate-files found, as CandidateInventory reads it from the project, after a commit when given.
      #: (?after: String?, ?also: Array[String], ?only: Array[String]) -> CandidateInventory
      def candidate_files(after: nil, also: [], only: [])
        mapped = after ? principles.readable_paths : []
        search_paths = SurveySearchPaths.new(recorded: guidance_search_paths.globs, also:, only:)
        CandidateInventory.read(@files, history, search_paths:, after:, mapped:)
      end

      #: (Array[String]) -> CandidateInventory
      def candidate_outlines(paths) = CandidateInventory.requested(@files, history, paths:)

      private

      # Refuses while the maps or records are still in the folder's earlier name.
      #: () -> void
      def refuse_unmoved_folder
        PrinciplesFolderMove.new(@maps.held_in | @audits.held_in).refuse_while_pending
      end
    end
  end
end
