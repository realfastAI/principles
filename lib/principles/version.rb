# typed: strict
# frozen_string_literal: true

module Principles
  # The next production release, as major.minor.patch. A production build is versioned with this alone.
  RELEASE = "0.1.4"
  # The version a built gem prints. `rake build[production]` stamps RELEASE here, in the copy of lib/ it
  # packages, and `rake build[development]` stamps RELEASE.g<short sha>. A checkout leaves it nil, and
  # Data::RunningVersion reads the commit this tool runs from instead.
  BUILT_VERSION = "0.1.4" #: String?
end
