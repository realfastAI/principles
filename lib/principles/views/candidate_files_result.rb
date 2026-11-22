# typed: strict
# frozen_string_literal: true

require_relative "invocation"
require_relative "prompts"

module Principles
  # What this tool prints, from plain values a controller hands it. views/CLAUDE.md owns the boundary.
  module Views
    # list-candidate-files' result: the files that look like agent guidance, and the question of which
    # principle several of them reinforce, asked before anything is mapped.
    class CandidateFilesResult
      # What the search for candidates found, as plain values: the inventory, the files git does not track, nil
      # outside git, where nothing checked them, and the lists to ask the owner about, each with the paths to
      # name in it.
      class Found
        # What each listed file prints: where it is, how big, where a link leads, and what the survey reads of it.
        PRINTED_FILE_FIELDS = %w[path characters symlink_to changed_in_range skill_file_spelt description opening_line
                                 outline].freeze

        #: Hash[String, Array[String]]
        attr_reader :owner_asks

        # Whether the inventory names files whose list items were cut to keep the result short.
        #: () -> bool
        def cut? = @inventory.key?("outlines_cut")

        # Whether the inventory names files that print their path and size alone, their outlines left out.
        #: () -> bool
        def left_out? = @inventory.key?("outlines_left_out")

        # What the outlines of the files a range changed print, when every cut left them past the budget.
        #: () -> Integer?
        def range_outlines_bytes = @inventory["range_outlines_bytes"]

        # conventional says whether the survey looked in the places hosts load by convention, as it does
        # unless --only narrowed it to its globs' matches.
        #: (inventory: Hash[String, untyped], untracked: Array[String]?,
        #|  owner_asks: Hash[String, Array[String]], ?conventional: bool) -> void
        def initialize(inventory:, untracked:, owner_asks:, conventional: true)
          @inventory = inventory
          @untracked = untracked
          @owner_asks = owner_asks
          @conventional = conventional
          freeze
        end

        # The inventory as printed: each file by path, size and link, where the inventory looks, and untracked only
        # in git.
        #: () -> Hash[String, untyped]
        def listed
          files = @inventory.fetch("files").map { |file| file.slice(*PRINTED_FILE_FIELDS) }
          scope = if @conventional then Prompts.text("find-a-principle-to-map/where-the-inventory-looks")
                  else Prompts.text("find-a-principle-to-map/where-a-survey-with-only-looks")
                  end
          listed = @inventory.merge("files" => files, "scope" => scope)
          @untracked ? listed.merge("untracked" => @untracked) : listed
        end
      end

      # The placeholders the printed create-principle command leaves for the agent to fill.
      CREATE_PRINCIPLE_USAGE = "ID --description \"What the principle is and why it matters\""

      #: (Invocation) -> void
      def initialize(invocation)
        @invocation = invocation
        freeze
      end

      # The inventory, and the question of which principle to map, with one item for each list under found's owner_asks
      # to ask the owner about.
      #: (Found, existing_maps: Array[String], map_file: String,
      #|  mapped_principles: Array[Hash[String, untyped]]) -> Hash[String, untyped]
      def question(found, existing_maps:, map_file:, mapped_principles:)
        survey, choice = survey_questions(existing_maps)
        result = { "status" => "question", "inventory" => found.listed, "existing_maps" => existing_maps,
                   "writes" => Prompts.text("find-a-principle-to-map/what-each-command-writes", map_file: map_file),
                   "question" => principle_question(found, survey: survey, choice: choice),
                   "answer_with" => mapping_answer(existing_maps),
                   **(mapped_principles.empty? ? {} : { "mapped_principles" => mapped_principles }) }
        existing_maps.empty? ? result : instructions_first(result)
      end

      private

      # Keep the survey's next action and existing-map comparison ahead of a potentially large inventory.
      #: (Hash[String, untyped]) -> Hash[String, untyped]
      def instructions_first(result)
        result.slice("status", "question", "answer_with", "mapped_principles", "existing_maps").merge(result)
      end

      # The table instructions and its later choice, with or without mapped rules to compare against.
      #: (Array[String]) -> [String, String]
      def survey_questions(existing_maps)
        if existing_maps.empty?
          [Prompts.text("find-a-principle-to-map/choose-one-principle"),
           Prompts.text("find-a-principle-to-map/ask-which-principle-to-map")]
        else
          [Prompts.text("find-a-principle-to-map/compare-with-mapped-principles"),
           Prompts.text("find-a-principle-to-map/choose-an-existing-or-new-principle")]
        end
      end

      # The map writes available after the table: extending an existing principle or starting a distinct one.
      #: (Array[String]) -> String
      def mapping_answer(existing_maps)
        create = @invocation.in_project("create-principle", usage: CREATE_PRINCIPLE_USAGE)
        return create if existing_maps.empty?

        add = @invocation.in_project("add-member", usage: "ID PATH --role ROLE")
        "To add a member to an existing principle: #{add}\nTo map a distinct principle: #{create}"
      end

      # The survey, leaving out files possibly test data, and when outlines were cut or left out how to read them, then
      # one item per list to ask the owner about after the table.
      #: (Found, survey: String, choice: String) -> String
      def principle_question(found, survey:, choice:)
        owner_asks = found.owner_asks
        asks = owner_asks.map { |key, paths| "- #{owner_ask(key, named: inline(paths))}" }
        [survey, *left_out_of_the_survey(owner_asks),
         *budget_notes(found),
         choice,
         Prompts.text("find-a-principle-to-map/ask-about-other-guidance-search-paths"),
         *([Prompts.text("find-a-principle-to-map/ask-the-owner-after-the-table"), *asks].join("\n") if asks.any?)]
          .join("\n\n")
      end

      # How to read what the budget cut: a cut section back by its lines, and a file whose outline was left out.
      #: (Found) -> Array[String]
      def budget_notes(found)
        [*(Prompts.text("find-a-principle-to-map/read-a-cut-section-back") if found.cut?),
         *(Prompts.text("find-a-principle-to-map/read-left-out-files") if found.left_out?),
         *range_past_budget(found.range_outlines_bytes)]
      end

      # How to survey a range whose own outlines pass the budget, given what they print; nothing when they do not.
      #: (Integer?) -> Array[String]
      def range_past_budget(bytes)
        bytes ? [Prompts.text("find-a-principle-to-map/survey-a-later-range", bytes: bytes.to_s)] : []
      end

      # The line leaving files possibly test data out of the survey, when any is listed.
      #: (Hash[String, Array[String]]) -> Array[String]
      def left_out_of_the_survey(owner_asks)
        return [] unless owner_asks.key?("possibly_test_data")

        [Prompts.text("find-a-principle-to-map/leave-test-data-out-of-the-survey")]
      end

      # The paths an ask names after its list's name, each quoted, since a path may hold a comma; none, nothing.
      #: (Array[String]) -> String
      def inline(paths) = paths.empty? ? "" : " (#{paths.map { |path| "`#{path}`" }.join(", ")})"

      # The ask about one inventory list, naming the paths after the list's name.
      #: (String, named: String) -> String
      def owner_ask(key, named:)
        case key
        when "possibly_test_data" then Prompts.text("find-a-principle-to-map/owner-ask-possibly-test-data", named:)
        when "untracked" then Prompts.text("find-a-principle-to-map/owner-ask-untracked", named:)
        when "ignored" then Prompts.text("find-a-principle-to-map/owner-ask-ignored", named:)
        when "ignored_folders" then Prompts.text("find-a-principle-to-map/owner-ask-ignored-folders", named:)
        else raise ArgumentError, "no owner ask for #{key}"
        end
      end
    end
  end
end
