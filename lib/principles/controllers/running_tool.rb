# typed: strict
# frozen_string_literal: true

require_relative "../models/feature"
require_relative "../models/meta_principle"
require_relative "../models/principles_package"
require_relative "../models/principles_on_path"
require_relative "../models/runs_from"
require_relative "../views/invocation"
require_relative "../views/meta_principle_passage"

module Principles
  # Each runs one command: reads models, applies their rules and prints through a view.
  # controllers/CLAUDE.md owns the boundary.
  module Controllers
    # This run of the tool, as its entry point was invoked: the executable every printed command names, and the
    # version running, which only the command line can read; and so the release of principles it comes from.
    class RunningTool
      # The command a printed command names when a bare principles runs this same copy, the name the plugin's
      # entry point gives itself for the same reason.
      ON_PATH = Models::RunsFrom::PLUGIN_EXECUTABLE

      # The folders the process was given, as Launch reads them: cwd, the one this run was started in, by its real
      # path, or nil when it is gone; temp_directory, its temporary folder, where a printed next step saves an answer.
      class Folders
        #: String?
        attr_reader :cwd
        #: String
        attr_reader :temp_directory

        #: (temp_directory: String, ?cwd: String?) -> void
        def initialize(temp_directory:, cwd: nil)
          @cwd = cwd
          @temp_directory = temp_directory
          freeze
        end
      end

      # What PATH says of this run, as Launch reads it, each read only when a command needs it: other gives the path
      # and printed version of another principles earlier on PATH than this one, and which of the commands it is
      # asked about that copy does not run, or nil, since reading it starts that copy; launched says whether this run
      # was launched as the first principles on PATH, as a RubyGems binstub is, so a bare principles runs this same
      # copy; tool says whether PATH holds a fast standard tool, such as rg, which a feature runs. Nothing is on PATH
      # unless Launch says so, so a feature that needs a tool is off by default.
      class OnPath
        #: (?other: ^(Array[String]) -> [String, String, Array[String]]?, ?launched: ^() -> bool,
        #|  ?tool: ^(String) -> bool) -> void
        def initialize(other: ->(_) {}, launched: -> { false }, tool: ->(_) { false })
          @other = other
          @launched = launched
          @tool = tool
          freeze
        end

        # The feature command runs, on only while PATH holds every fast standard tool it needs.
        #: (String) -> Models::Feature
        def feature(command) = Models::Feature.new(command, on_path: @tool)

        # Another principles earlier on PATH, asked about the commands of asking, or nil.
        #: (Array[String]) -> [String, String, Array[String]]?
        def other(asking) = @other.call(asking)

        #: () -> bool
        def launched? = @launched.call
      end

      # version gives the version running, read only when a command needs it, since in a checkout reading it
      # asks git; on_path is what PATH says of this run; folders are the folders the process was given.
      #: (executable: String, version: ^() -> String, folders: Folders, ?on_path: OnPath) -> void
      def initialize(executable:, version:, folders:, on_path: OnPath.new)
        @executable = executable
        @version = version
        @on_path = on_path
        @folders = folders
        freeze
      end

      # The executable every printed command names: the bare principles when that runs this copy, else the entry
      # point's own.
      #: () -> String
      def executable = bare_from_path? ? ON_PATH : @executable

      #: () -> String
      def version = @version.call

      # Whether this run was launched as the first principles on PATH, so a bare principles runs this same copy.
      #: () -> bool
      def launched_on_path? = @on_path.launched?

      # Where this run comes from, by the entry point it was invoked through, whatever its commands are printed as.
      #: () -> Models::RunsFrom
      def runs_from = Models::RunsFrom.new(@executable)

      # The executable and project that this run's printed commands name, for the project at root. A command line run
      # printed as the bare principles, from root itself, leaves out --project, since a command copied from its
      # output runs there too; any other run names the project, as the plugin's hooks and a checkout's commands may
      # be run from elsewhere. answer_folder is the project's own folder for a printed answer, when it has one, which
      # every answer file is saved in rather than the temporary folder.
      #: (String, ?answer_folder: String?) -> Views::Invocation
      def invocation(root, answer_folder: nil)
        Views::Invocation.new(executable: executable, project: root,
                              temp_directory: answer_folder || @folders.temp_directory,
                              named: !bare_from_path? || root != @folders.cwd)
      end

      # Another principles earlier on PATH than this one, which a bare principles command runs in its place, asked
      # whether it runs each command of asking, or nil.
      #: (?asking: Array[String]) -> Models::PrinciplesOnPath?
      def other_on_path(asking: [])
        path, version, lacking = @on_path.other(asking)
        path && version ? Models::PrinciplesOnPath.new(path, version, lacking: lacking || []) : nil
      end

      # The feature command runs, on only while PATH holds every fast standard tool it needs.
      #: (String) -> Models::Feature
      def feature(command) = @on_path.feature(command)

      # The release of principles this run comes from, as the audit of map's principle keeps it: the version running
      # and the passage as setup prints it, which only a view holds; nil for a principle whose audit keeps none.
      #: (Models::Principle) -> Models::PrinciplesPackage?
      def release_kept_by(map)
        return unless map.keeps_package?

        passage = Views::MetaPrinciplePassage.new(heading: Models::MetaPrinciple::PASSAGE_HEADING).text
        Models::PrinciplesPackage.of(version: version, passage: passage)
      end

      private

      # Whether a command line run, not the plugin's, was launched as the first principles on PATH, so its commands
      # are printed as the bare principles.
      #: () -> bool
      def bare_from_path? = @executable != ON_PATH && launched_on_path?
    end
  end
end
