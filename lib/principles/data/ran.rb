# typed: strict
# frozen_string_literal: true

require "open3"

module Principles
  # Every file and process this tool reads or writes. data/CLAUDE.md owns the boundary.
  module Data
    # One run of a command in a folder: what it printed, and its exit status.
    module Ran
      # What command printed, run in folder with its errors going to errors_path, and its exit status, nil for one
      # stopped by a signal.
      #: (Array[String], String, String) -> [String, Integer?]
      def self.run(command, folder, errors_path)
        printed = ""
        status = nil #: Integer?
        Open3.pipeline_r(command, chdir: folder, err: errors_path) do |output, waits|
          printed = output.read
          status = waits.fetch(0).value.exitstatus
        end
        [printed, status]
      end
    end
  end
end
