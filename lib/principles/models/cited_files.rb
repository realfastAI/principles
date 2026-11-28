# typed: strict
# frozen_string_literal: true

require_relative "assessment_report"
require_relative "project_history"
require_relative "installed_plugins"
require_relative "plugin_reference"

module Principles
  # The domain logic, and the mediation of persistence. models/CLAUDE.md owns the boundary.
  module Models
    # The files an audit record cites, through its assessments' evidence and its findings' evidence and write-ups, as
    # the project holds them now: which go with the record when its completed audit is committed, since a clone needs
    # every file the record points at, and which no longer exist, though the record still points at them.
    class CitedFiles
      # paths are the files the record cites; in_git says whether its audit had a base commit to compare with.
      #: (Array[String], ProjectHistory, in_git: bool) -> void
      def initialize(paths, history, in_git:)
        @paths = paths
        @history = history
        @in_git = in_git
        freeze
      end

      # The files to commit with the record, sorted once each: each file the audit changed; in git, with each cited
      # file, only those that still differ from HEAD, since a fix the agent already committed needs nothing. A cited
      # file deleted since is left out, since adding it would stage a deletion the audit never made; a file its
      # fixes deleted stays. What reported cites that the record does not keep, as the answer's recent decision's
      # paths, is cited too.
      #: (Array[String], ?AssessmentReport) -> Array[String]
      def committed_with(changed, reported = AssessmentReport::NONE)
        changed = @history.uncommitted(changed + @history.existing(@paths + reported.recent_decision_paths)) if @in_git
        changed.uniq.sort
      end

      # Each cited file that no longer exists, in git or outside it; a plugin's file, which is not in the project,
      # when the plugin installed now does not hold it.
      #: (InstalledPlugins) -> Array[String]
      def missing(plugins)
        existing = @history.existing(@paths)
        @paths.reject do |path|
          reference = PluginReference.in(path)
          reference ? plugins.holds?(reference) : existing.include?(path)
        end
      end
    end
  end
end
