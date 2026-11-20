---
name: setup-ruby
description: Use when `principles` refuses with unsupported_ruby, or when `principles --version` fails, to install the Ruby 3.4 the `principles` command needs with rbenv and ruby-build. It asks the user before installing anything.
disable-model-invocation: true
---

# Set up the Ruby the principles command needs

`principles` runs on Ruby 3.4, from 3.4.2 up to but not including 3.5. When the Ruby on the PATH is another
version, `principles` looks for a Ruby 3.4 that rbenv installed, in `$RBENV_ROOT` or `~/.rbenv`, and runs itself
on that. So this setup installs one Ruby 3.4 with rbenv and changes nothing else. It sets no global Ruby and
does not touch the user's shell profile.

## 1. See whether anything is needed

Run `principles --version`. If it prints a version, Ruby is already set up: stop here and say so.

Otherwise, find out what is already installed:

```sh
command -v brew; command -v rbenv; ls "${RBENV_ROOT:-$HOME/.rbenv}/versions" 2>/dev/null
```

## 2. Ask the user before installing anything

Ask the user to approve installation, showing the exact commands you will run and what each one installs.
Leave out a step whose tool is already installed. Installing needs the network, and it writes outside the
project, under Homebrew's prefix and `~/.rbenv`. If your sandbox refuses either, give the user the commands
to run themselves, each typed after `!` so its output lands in this session.

On macOS with Homebrew:

```sh
brew install rbenv ruby-build
rbenv install --list | grep -E '^3\.4\.[0-9]+$' | tail -1    # the newest Ruby 3.4
rbenv install 3.4.N                                             # N from the line above
```

On Linux, or without Homebrew, first install the build dependencies that ruby-build's wiki lists for the
system, then:

```sh
git clone https://github.com/rbenv/rbenv.git ~/.rbenv
git clone https://github.com/rbenv/ruby-build.git ~/.rbenv/plugins/ruby-build
~/.rbenv/bin/rbenv install --list | grep -E '^3\.4\.[0-9]+$' | tail -1
~/.rbenv/bin/rbenv install 3.4.N
```

Run nothing until the user says yes.

## 3. Check it worked

Run `principles --version` again. It should print a version from any directory. If it still refuses, show the
user its `message`, which names the Ruby that ran and what was looked for.

## 4. Say what was installed and how to undo it

Tell the user exactly what you installed and where, and how to remove each piece:

- the Ruby: `rbenv uninstall 3.4.N`
- rbenv and ruby-build, if you installed them with Homebrew: `brew uninstall ruby-build rbenv`
- rbenv and ruby-build, if you cloned them: `rm -rf ~/.rbenv`, after checking it holds no other Ruby the user
  wants to keep
