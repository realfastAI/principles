# typed: strict
# frozen_string_literal: true

require_relative "../error"
require_relative "../prose_list"
require_relative "../data/claude_code_home"
require_relative "plugin_install"
require_relative "plugin_component"
require_relative "plugin_name"
require_relative "installed_component"
require_relative "member_file"

module Principles
  # The domain logic, and the mediation of persistence. models/CLAUDE.md owns the boundary.
  module Models
    # The plugins Claude Code installed that a session in the project loads, as the registry in its home records them;
    # none while it has installed none.
    class InstalledPlugins
      # The most files a refusal names; it counts the rest.
      LISTED = 20 #: Integer

      # The marketplace kinds whose plugins Claude Code copies into the install folder its registry names, which is
      # where a session reads them.
      COPIED = %w[github git url].freeze #: Array[String]

      #: (Data::ClaudeCodeHome, main_checkout: String) -> void
      def initialize(claude_code, main_checkout:)
        @claude_code = claude_code
        @main_checkout = main_checkout
        freeze
      end

      # The install of the plugin named that a session here loads, refused when there is none, naming those there
      # are; when its marketplace is a local folder, whose session reads the folder rather than the install; and when
      # its marketplace is of no kind COPIED names, since a session may read that from elsewhere too.
      #: (String) -> PluginInstall
      def install(name)
        install = PluginInstall.applying(rows(name), main_checkout: @main_checkout) or refuse_not_installed(name)
        kind = @claude_code.marketplaces&.source_kind(PluginName.new(name).marketplace)
        refuse_directory_marketplace(name) if kind == "directory"
        refuse_unknown_marketplace(name) unless COPIED.include?(kind)
        install.version.to_s.empty? ? refuse_unversioned(name) : install
      end

      # The file component names in the plugin named, with its text, refused when it is reached through a symbolic
      # link, which this tool never follows; when the plugin holds no such file, naming those it does; and when its
      # text is not UTF-8 or larger than this tool reads.
      #: (String, PluginComponent) -> InstalledComponent
      def holding(name, component)
        install = install(name)
        folder = @claude_code.plugin_folder(install.install_path.to_s)
        refuse_linked(name, component) if folder.linked?(component.path)
        refuse_not_held(name, folder.files) unless folder.file?(component.path)
        InstalledComponent.new(PluginReference.new(name, component), install, folder.read(component.path))
      end

      # Whether the plugin installed now holds the file reference names, as holding finds it.
      #: (PluginReference) -> bool
      def holds?(reference)
        holding(reference.name, reference.component)
        true
      rescue Error
        false
      end

      # Where the file reference names comes from, at the version installed now, refused as install refuses.
      #: (PluginReference) -> Hash[String, untyped]
      def source(reference) = reference.source(install(reference.name).version)

      # Where member comes from when a plugin gives it, as source says; nil for a member in a project file.
      #: (Member) -> Hash[String, untyped]?
      def source_of(member)
        reference = member.plugin_reference or return
        source(reference)
      end

      # The file a mapped plugin member's reference names, as the type that finds the member in it, refused as
      # holding refuses it.
      #: (PluginReference) -> MemberFile
      def member_file(reference)
        MemberFile.for(path: reference.to_s, text: holding(reference.name, reference.component).text)
      end

      # The install names of the plugins a session here loads, sorted.
      #: () -> Array[String]
      def names
        (@claude_code.registry&.names || []).select do |name|
          PluginInstall.applying(rows(name), main_checkout: @main_checkout)
        end
      end

      private

      #: (String) -> Array[Hash[String, String?]]
      def rows(name) = @claude_code.registry&.rows(name) || []

      #: (String, Array[String]) -> bot
      def refuse_not_held(name, files)
        plain, skipped = files.partition { |path| PluginComponent.plain?(path) }
        listed = plain.first(LISTED) + (plain.size > LISTED ? ["#{plain.size - LISTED} more"] : [])
        repair = if listed.empty?
                   "#{name} holds no file this tool can map.#{left_out(skipped, "")} Map the project's own files " \
                     "instead."
                 else
                   "Name one of the files #{name} holds: #{ProseList.new(listed)}.#{left_out(skipped, " more")}"
                 end
        raise Error.new("plugin_component_not_found", "#{name} holds no such file", repair)
      end

      # A sentence, after a space, counting the files skipped that a refusal leaves out for their paths, as more
      # when it lists others; nothing when there are none.
      #: (Array[String], String) -> String
      def left_out(skipped, more)
        return "" if skipped.empty?

        " #{skipped.size}#{more} #{skipped.one? ? "is" : "are"} left out, since a member's path takes only plain " \
          "characters."
      end

      #: (String, PluginComponent) -> bot
      def refuse_linked(name, component)
        raise Error.new("plugin_component_linked",
                        "#{component.path} in #{name} is reached through a symbolic link, which this tool does not " \
                        "follow, since it could lead out of the plugin",
                        "Name the file the link leads to by its own path inside the plugin, or map the project's own " \
                        "files instead.")
      end

      #: (String) -> bot
      def refuse_directory_marketplace(name)
        raise Error.new("plugin_from_directory_marketplace", "#{name} comes from a marketplace in a local folder",
                        "Map the project's own files instead; a plugin from a marketplace in a local folder is " \
                        "not supported yet.")
      end

      # A probe saw the host record a version in every row, a commit's first digits when the plugin names none.
      #: (String) -> bot
      def refuse_unversioned(name)
        raise Error.new("unreadable_plugin_registry", "Claude Code's plugin registry records no version for #{name}",
                        "Reinstall the plugin with Claude Code, or map the project's own files instead.")
      end

      #: (String) -> bot
      def refuse_unknown_marketplace(name)
        raise Error.new("plugin_marketplace_unknown",
                        "Claude Code records no marketplace kind this tool reads for #{name}",
                        "Map the project's own files instead; this tool reads a plugin only from a marketplace " \
                        "Claude Code records as #{ProseList.new(COPIED, conjunction: "or")}.")
      end

      #: (String) -> bot
      def refuse_not_installed(name)
        here = names
        choices = if here.empty?
                    "No plugin is installed for this project. Install #{name} with Claude Code first."
                  else
                    "Installed for this project: #{ProseList.new(here)}. Name one of them with --plugin, or install " \
                      "#{name} with Claude Code first."
                  end
        repair = elsewhere(name) + choices
        raise Error.new("plugin_not_installed", "#{name} is not installed for this project", repair)
      end

      # Why name's rows, when it has some, do not apply here: each installs it for another project.
      #: (String) -> String
      def elsewhere(name)
        return "" if rows(name).empty?

        "#{name} is installed only for another project, and only a user-scope install is read outside its own " \
          "project. "
      end
    end
  end
end
