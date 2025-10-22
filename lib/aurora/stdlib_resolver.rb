# frozen_string_literal: true

module Aurora
  # Resolves stdlib module names to file paths
  class StdlibResolver
    # Map of stdlib module names to their file paths
    STDLIB_MODULES = {
      'Math' => 'math.aur',
      'IO' => 'io.aur',
      'Collections' => 'collections.aur',
      'String' => 'string.aur',
      'Option' => 'option.aur',
      'Result' => 'result.aur'
    }.freeze

    def initialize(stdlib_dir = nil)
      @stdlib_dir = stdlib_dir || File.expand_path('../aurora/stdlib', __dir__)
    end

    # Check if a module name is a stdlib module
    def stdlib_module?(name)
      STDLIB_MODULES.key?(name)
    end

    # Resolve a module name to a file path
    # Returns nil if not a stdlib module
    def resolve(name)
      return nil unless stdlib_module?(name)

      file = STDLIB_MODULES[name]
      path = File.join(@stdlib_dir, file)

      File.exist?(path) ? path : nil
    end

    # Get all available stdlib module names
    def available_modules
      STDLIB_MODULES.keys
    end
  end
end
