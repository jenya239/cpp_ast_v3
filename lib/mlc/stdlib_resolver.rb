# frozen_string_literal: true

require_relative 'stdlib_scanner'

module MLC
  # Resolves stdlib module names to file paths
  # Now uses StdlibScanner for automatic discovery
  class StdlibResolver
    # DEPRECATED: Legacy constant for backward compatibility
    # Use StdlibScanner for automatic module discovery
    STDLIB_MODULES = {
      'Math' => 'math.mlc',
      'IO' => 'io.mlc',
      'String' => 'string.mlc',
      'Conv' => 'conv.mlc',
      'Graphics' => 'graphics.mlc'
    }.freeze

    def initialize(stdlib_dir = nil, scanner: nil)
      @stdlib_dir = stdlib_dir || File.expand_path('stdlib', __dir__)
      @scanner = scanner || StdlibScanner.new(@stdlib_dir)
    end

    # Check if a module name is a stdlib module
    def stdlib_module?(name)
      @scanner.module_exists?(name)
    end

    # Resolve a module name to a file path
    # Returns nil if not a stdlib module
    def resolve(name)
      @scanner.module_file_path(name)
    end

    # Get all available stdlib module names
    def available_modules
      @scanner.available_modules
    end

    # Get the scanner instance (for accessing function/type metadata)
    def scanner
      @scanner
    end
  end
end
