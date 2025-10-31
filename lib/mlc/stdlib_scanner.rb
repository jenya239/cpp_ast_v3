# frozen_string_literal: true

require_relative 'parser/parser'
require_relative 'ast/nodes'

module MLC
  # Metadata for a stdlib function
  class FunctionMetadata
    attr_reader :name, :qualified_name, :extern, :params, :return_type, :ast_node

    def initialize(name:, qualified_name:, extern:, params:, return_type:, ast_node:)
      @name = name
      @qualified_name = qualified_name
      @extern = extern
      @params = params
      @return_type = return_type
      @ast_node = ast_node
    end

    def extern?
      @extern
    end
  end

  # Metadata for a stdlib type
  class TypeMetadata
    attr_reader :name, :qualified_name, :opaque, :fields, :ast_node

    def initialize(name:, qualified_name:, opaque:, fields: [], ast_node:)
      @name = name
      @qualified_name = qualified_name
      @opaque = opaque
      @fields = fields
      @ast_node = ast_node
    end

    def opaque?
      @opaque
    end
  end

  # Information about a stdlib module
  class ModuleInfo
    attr_reader :name, :namespace, :file_path, :functions, :types

    def initialize(name:, namespace:, file_path:, functions:, types:)
      @name = name
      @namespace = namespace
      @file_path = file_path
      @functions = functions  # Hash: function_name => FunctionMetadata
      @types = types          # Hash: type_name => TypeMetadata
    end
  end

  # Automatically scans stdlib directory and extracts module metadata
  # Eliminates need for manual STDLIB_MODULES and STDLIB_FUNCTIONS registration
  class StdlibScanner
    def initialize(stdlib_dir = nil)
      @stdlib_dir = stdlib_dir || File.expand_path('stdlib', __dir__)
      @modules = {}           # module_name => ModuleInfo
      @function_map = {}      # function_name => qualified_name
      @scanned = false
    end

    # Scan all stdlib modules in directory
    def scan_all
      return if @scanned

      Dir.glob(File.join(@stdlib_dir, '*.mlc')).each do |file_path|
        begin
          module_info = scan_module(file_path)
          @modules[module_info.name] = module_info

          # Build flat function mapping for quick lookup
          module_info.functions.each do |func_name, metadata|
            @function_map[func_name] = metadata.qualified_name
          end
        rescue => e
          # Log error but continue scanning other modules
          warn "Failed to scan #{file_path}: #{e.message}"
        end
      end

      @scanned = true
    end

    # Get C++ qualified name for a function
    # Returns nil if function not found
    def cpp_function_name(function_name)
      scan_all unless @scanned
      @function_map[function_name]
    end

    # Get all available stdlib module names
    def available_modules
      scan_all unless @scanned
      @modules.keys
    end

    # Get module info by name
    # Returns nil if module not found
    def module_info(module_name)
      scan_all unless @scanned
      @modules[module_name]
    end

    # Check if a module exists
    def module_exists?(module_name)
      scan_all unless @scanned
      @modules.key?(module_name)
    end

    # Get file path for a module
    # Returns nil if module not found
    def module_file_path(module_name)
      module_info(module_name)&.file_path
    end

    private

    # Scan a single stdlib module file
    def scan_module(file_path)
      source = File.read(file_path)
      ast = MLC.parse(source)

      # Extract module name from declaration or filename
      module_name = if ast.respond_to?(:module_decl) && ast.module_decl
        ast.module_decl.name
      else
        # Fallback: use filename (capitalize first letter)
        File.basename(file_path, '.mlc').capitalize
      end

      namespace = infer_namespace(module_name)

      functions = {}
      types = {}

      # Extract exported declarations and extern functions
      # Note: extern functions are implicitly available for import even without 'export'
      ast.declarations.each do |decl|
        case decl
        when AST::FuncDecl
          if decl.exported || decl.external
            functions[decl.name] = create_function_metadata(decl, namespace)
          end
        when AST::TypeDecl
          if decl.exported
            types[decl.name] = create_type_metadata(decl, namespace)
          end
        end
      end

      ModuleInfo.new(
        name: module_name,
        namespace: namespace,
        file_path: file_path,
        functions: functions,
        types: types
      )
    end

    # Create function metadata from AST declaration
    def create_function_metadata(decl, namespace)
      FunctionMetadata.new(
        name: decl.name,
        qualified_name: "#{namespace}::#{decl.name}",
        extern: decl.external,
        params: decl.params.map { |p| { name: p.name, type: p.type } },
        return_type: decl.ret_type,
        ast_node: decl
      )
    end

    # Create type metadata from AST declaration
    def create_type_metadata(decl, namespace)
      opaque = decl.type.is_a?(AST::OpaqueType)
      fields = extract_fields(decl.type)

      TypeMetadata.new(
        name: decl.name,
        qualified_name: "#{namespace}::#{decl.name}",
        opaque: opaque,
        fields: fields,
        ast_node: decl
      )
    end

    # Extract fields from record type
    def extract_fields(type)
      return [] unless type.is_a?(AST::RecordType)

      type.fields.map do |field|
        {
          name: field[:name],
          type: field[:type]
        }
      end
    end

    # Infer C++ namespace from MLC module name
    # Convention: ModuleName -> mlc::modulename
    # Special cases handled here
    def infer_namespace(module_name)
      case module_name
      when 'Array'
        'mlc::collections'
      when 'Conv'
        # Conv functions are in mlc namespace (mlc_string.hpp)
        'mlc'
      when 'IO'
        # Preserve uppercase for IO
        'mlc::io'
      else
        # Default: lowercase the module name
        "mlc::#{module_name.downcase}"
      end
    end
  end
end
