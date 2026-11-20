# frozen_string_literal: true

require_relative "lib/principles/version"

Gem::Specification.new do |spec|
  spec.name = "principles"
  # `rake build[development]` or `rake build[production]` stamps the version into the copy it builds; see the
  # Rakefile. Loaded from the checkout, as Bundler does, it is RELEASE, so Gemfile.lock does not change with
  # every commit.
  spec.version = Principles::BUILT_VERSION || Principles::RELEASE
  spec.summary = "Tighter harness, longer leash: agents you can leave running"
  spec.description = <<~TEXT
    A harness configuration framework that keeps every part of your Claude Code agent's harness in alignment.
    Name the principles your CLAUDE.md files, rules, skills, subagents and hooks encode, and map every place
    that carries each one. When one place changes, the principles CLI helps your agent track which others must
    move with it, and walks your agent through bringing them back into line, recording anything still to fix.
    It never edits your harness and calls no model: it keeps the books deterministically.
    Ruby 3.4, with no runtime gem dependencies.
    Codex and Pi support coming soon.
  TEXT
  spec.license = "Apache-2.0"
  spec.authors = ["Sidu Ponnappa"]
  spec.email = ["sidu@realfast.ai"]
  spec.required_ruby_version = [">= 3.4.2", "< 3.5"]
  spec.homepage = "https://github.com/realfastAI/principles"
  spec.metadata["source_code_uri"] = spec.homepage
  spec.metadata["changelog_uri"] = "#{spec.homepage}/blob/main/CHANGELOG.md"
  spec.metadata["bug_tracker_uri"] = "#{spec.homepage}/issues"

  # An allowlist of what the CLI runs on: its executable, its Ruby, its data and schemas, and the prompts it prints.
  # With the licence and its NOTICE, which Apache 2.0 requires on every copy, and the README, changelog and this
  # gemspec, which the public repository carries as the gem does, and nothing else, so no harness component, such
  # as a CLAUDE.md or a skill, reaches the gem.
  spec.files = ["CHANGELOG.md", "LICENSE", "NOTICE", "README.md", "exe/principles", "principles.gemspec",
                *Dir["lib/**/*.rb", "lib/principles/data/**/*.json",
                     "lib/principles/views/prompts/**/*.{md,json}"]].sort
  spec.bindir = "exe"
  spec.executables = ["principles"]
  spec.require_paths = ["lib"]
  # No runtime dependency: this tool runs on the standard library alone, so it starts on any Ruby that
  # satisfies required_ruby_version. A run checks files against their schemas with its own validator;
  # json_schemer is a development dependency that the specs compare it with.
  spec.metadata["rubygems_mfa_required"] = "true"
end
