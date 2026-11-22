# typed: strict
# frozen_string_literal: true

require "tmpdir"
require_relative "version"
require_relative "data/running_version"
require_relative "data/principles_on_path"
require_relative "controllers/running_tool"

module Principles
  # This process as its entry point launched it: the executable that entry point names itself by, the file it was
  # launched as, PATH, the folder it started in and its temporary folder, read here so that no layer reads them. It
  # gives every controller the same RunningTool.
  class Launch
    #: (String) -> void
    def initialize(executable)
      @executable = executable
      freeze
    end

    # This run of the tool: the executable it was invoked as, its version, and what PATH and its folder say of it,
    # each read only when a command needs it.
    #: () -> Controllers::RunningTool
    def running_tool
      Controllers::RunningTool.new(executable: @executable, version: -> { running_version },
                                   other_on_path: ->(asking) { on_path.other(asking) },
                                   launched_on_path: -> { on_path.own_first? },
                                   folders: Controllers::RunningTool::Folders.new(cwd: started_in,
                                                                                  temp_directory: Dir.tmpdir))
    end

    private

    # The folder this run was started in, by its real path, as a project's root is given, or nil when it is gone.
    #: () -> String?
    def started_in
      File.realpath(Dir.pwd)
    rescue SystemCallError
      nil
    end

    # The principles on PATH, against this run's own file: the plugin's bin or a RubyGems binstub when either
    # launched it, else this tool's executable.
    #: () -> Data::PrinciplesOnPath
    def on_path = Data::PrinciplesOnPath.new(ENV.fetch("PATH", ""), own: File.expand_path($PROGRAM_NAME))

    # The version of this tool that is running, as a build stamped it or a checkout's commit gives it.
    #: () -> String
    def running_version = Data::RunningVersion.new(release: RELEASE, built: BUILT_VERSION).to_s
  end
end
