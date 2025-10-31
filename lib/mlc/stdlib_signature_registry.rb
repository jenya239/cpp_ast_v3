# frozen_string_literal: true

require_relative "stdlib_scanner"

module MLC
  # Provides cached access to stdlib function/type signatures backed by StdlibScanner metadata.
  class StdlibSignatureRegistry
    attr_reader :scanner

    def initialize(scanner: StdlibScanner.new)
      @scanner = scanner
    end

    def module_info(module_name)
      scanner.module_info(module_name)
    end

    def available_modules
      scanner.available_modules
    end

    def functions_for(module_name)
      info = module_info(module_name)
      info ? info.functions : {}
    end

    def types_for(module_name)
      info = module_info(module_name)
      info ? info.types : {}
    end

    def function_metadata(module_name, function_name)
      functions_for(module_name)[function_name]
    end

    def type_metadata(module_name, type_name)
      types_for(module_name)[type_name]
    end
  end
end
