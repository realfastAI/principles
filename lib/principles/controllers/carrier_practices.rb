# typed: strict
# frozen_string_literal: true

require_relative "command"
require_relative "../models/carrier_kind"
require_relative "../views/carrier_practices_page"

module Principles
  # Each runs one command: reads models, applies their rules and prints through a view.
  # controllers/CLAUDE.md owns the boundary.
  module Controllers
    # show-carrier-practices KIND: the page of one carrier kind's practices, for an agent judging or editing a member
    # of that kind to read beyond the check a request prints. It writes nothing.
    class CarrierPractices < Command
      #: (String, String?, Hash[String, untyped]) -> untyped
      def call(command, _id, options)
        naming_the_executable do
          unknown(command) unless command == "show-carrier-practices"

          named = Models::CarrierKind.named(options.fetch("kind"))
          Views::CarrierPracticesPage.of(named).result(named)
        end
      end
    end
  end
end
