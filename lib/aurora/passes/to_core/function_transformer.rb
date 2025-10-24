# frozen_string_literal: true

module Aurora
  module Passes
    class ToCore
      # FunctionTransformer
      # Function and type declaration transformation
      # Auto-extracted from to_core.rb during refactoring
      module FunctionTransformer
      def ensure_function_signature(func_decl)
        register_function_signature(func_decl)
        @function_table[func_decl.name]
      end

      def refresh_function_signatures!(resolved_name)
        resolved = @type_table[resolved_name]
        return unless resolved

        @function_table.each_value do |info|
          info.param_types = info.param_types.map do |type|
            type_name(type) == resolved_name ? resolved : type
          end
          info.ret_type = resolved if type_name(info.ret_type) == resolved_name
        end
      end

      def register_function_signature(func_decl)
        return @function_table[func_decl.name] if @function_table.key?(func_decl.name)

        param_types = func_decl.params.map { |param| transform_type(param.type) }
        ret_type = transform_type(func_decl.ret_type)
        info = FunctionInfo.new(func_decl.name, param_types, ret_type)
        @function_table[func_decl.name] = info
      end

      def register_stdlib_imports(import_decl)
        # Check if this is a stdlib module
        resolver = StdlibResolver.new
        return unless resolver.stdlib_module?(import_decl.path)

        # Resolve the stdlib module path
        stdlib_path = resolver.resolve(import_decl.path)
        return unless stdlib_path

        # Parse the stdlib module
        source = File.read(stdlib_path)
        stdlib_ast = Aurora.parse(source)

        # Get the list of imported items (or all if import_all)
        imported_items = if import_decl.import_all
          # Import all exported functions
          stdlib_ast.declarations.select { |d| d.is_a?(AST::FuncDecl) && d.exported }.map(&:name)
        else
          import_decl.items || []
        end

        # Register signatures for imported functions
        stdlib_ast.declarations.each do |decl|
          next unless decl.is_a?(AST::FuncDecl)
          next unless imported_items.include?(decl.name)

          # Register the function signature
          param_types = decl.params.map { |param| transform_type(param.type) }
          ret_type = transform_type(decl.ret_type)
          @function_table[decl.name] = FunctionInfo.new(decl.name, param_types, ret_type)
        end

        # Register imported types (for member access support)
        # Determine namespace from import path
        namespace = infer_namespace_from_path(import_decl.path)

        stdlib_ast.declarations.each do |decl|
          next unless decl.is_a?(AST::TypeDecl)
          next unless imported_items.include?(decl.name)

          # Transform the type
          type_ir = transform_type_decl(decl)

          # Register in NEW TypeRegistry with namespace info
          kind = infer_type_kind(decl, type_ir.type)
          @type_registry.register(
            decl.name,
            ast_node: decl,
            core_ir_type: type_ir.type,
            namespace: namespace,
            kind: kind,
            exported: decl.exported
          )

          # Also register in OLD @type_table for backward compat
          @type_table[decl.name] = type_ir.type

          # If it's a sum type, register its constructors
          register_sum_type_constructors(decl.name, type_ir.type) if type_ir.type.is_a?(CoreIR::SumType)
        end
      end

      def register_sum_type_constructors(sum_type_name, sum_type)
        return unless sum_type.respond_to?(:variants)

        sum_type.variants.each do |variant|
          field_types = (variant[:fields] || []).map { |field| field[:type] }
          @sum_type_constructors[variant[:name]] = FunctionInfo.new(variant[:name], field_types, sum_type)
        end
      end

      # Helper: Infer C++ namespace from module path
      # @param path [String] Module path (e.g., "Graphics", "Math")
      # @return [String, nil] C++ namespace (e.g., "aurora::graphics")
      def infer_namespace_from_path(path)
        # Map stdlib module names to C++ namespaces
        STDLIB_NAMESPACE_MAP[path]
      end

      # Map of stdlib modules to their C++ namespaces
      STDLIB_NAMESPACE_MAP = {
        'Graphics' => 'aurora::graphics',
        'Math' => 'aurora::math',
        'IO' => 'aurora::io',
        'String' => 'aurora::string',
        'Conv' => 'aurora',  # Conv functions are directly in aurora namespace
        'File' => 'aurora::file',
        'JSON' => 'aurora::json',
        'Collections' => 'aurora::collections'
      }.freeze

      # Helper: Infer type kind from AST and CoreIR
      # @param ast_decl [AST::TypeDecl] AST type declaration
      # @param core_ir_type [CoreIR::Type] CoreIR type
      # @return [Symbol] :primitive, :record, :sum, :opaque
      def infer_type_kind(ast_decl, core_ir_type)
        # Check if it's an opaque type (type without definition)
        # In our parser, opaque types become PrimType with the same name as the decl
        if core_ir_type.is_a?(CoreIR::Type) &&
           core_ir_type.primitive? &&
           ast_decl.type.is_a?(AST::PrimType) &&
           ast_decl.type.name == ast_decl.name
          return :opaque
        end

        # Otherwise determine from CoreIR type
        return :record if core_ir_type.is_a?(CoreIR::RecordType)
        return :sum if core_ir_type.is_a?(CoreIR::SumType)
        return :primitive if core_ir_type.primitive?

        :unknown
      end

      def transform_function(func)
        with_current_node(func) do
          signature = ensure_function_signature(func)
          param_types = signature.param_types

          if param_types.length != func.params.length
            type_error("Function '#{func.name}' expects #{param_types.length} parameter(s), got #{func.params.length}")
          end

          params = func.params.each_with_index.map do |param, index|
            CoreIR::Param.new(name: param.name, type: param_types[index])
          end

          ret_type = signature.ret_type
          type_params = normalize_type_params(func.type_params)

          # For external functions, skip body transformation
          if func.external
            return CoreIR::Func.new(
              name: func.name,
              params: params,
              ret_type: ret_type,
              body: nil,
              effects: [],
              type_params: type_params,
              external: true
            )
          end

          saved_var_types = @var_types.dup
          saved_type_params = @current_type_params
          @function_return_type_stack.push(ret_type)

          # Save type parameters for constraint checking
          @current_type_params = type_params

          params.each do |param|
            @var_types[param.name] = param.type
          end

          body = transform_expression(func.body)

          unless void_type?(ret_type)
            ensure_compatible_type(body.type, ret_type, "function '#{func.name}' result")
          else
            type_error("function '#{func.name}' should not return a value") unless void_type?(body.type)
          end

          CoreIR::Func.new(
            name: func.name,
            params: params,
            ret_type: ret_type,
            body: body,
            effects: infer_effects(body),
            type_params: type_params
          )
        end
      ensure
        @function_return_type_stack.pop if @function_return_type_stack.any?
        @var_types = saved_var_types if defined?(saved_var_types)
        @current_type_params = saved_type_params if defined?(saved_type_params)
      end

      def transform_program(program)
        items = []
        imports = []

        # Transform imports
        program.imports.each do |import_decl|
          imports << CoreIR::Import.new(
            path: import_decl.path,
            items: import_decl.items
          )

          # Register stdlib function signatures
          register_stdlib_imports(import_decl)
        end

        # Pre-register type declarations for constraint checks
        program.declarations.each do |decl|
          @type_decl_table[decl.name] = decl if decl.is_a?(AST::TypeDecl)
        end

        # Pre-register function signatures to support recursion and forward references
        program.declarations.each do |decl|
          register_function_signature(decl) if decl.is_a?(AST::FuncDecl)
        end

        type_items = []
        func_items = []

        # Transform declarations (types first, then functions)
        program.declarations.each do |decl|
          case decl
          when AST::TypeDecl
            type_decl = transform_type_decl(decl)
            type_items << type_decl
            @type_table[decl.name] = type_decl.type
            refresh_function_signatures!(decl.name)
          when AST::FuncDecl
            func_items << transform_function(decl)
          end
        end

        items.concat(type_items)
        items.concat(func_items)

        # Get module name from module declaration or default to "main"
        module_name = program.module_decl ? program.module_decl.name : "main"

        CoreIR::Module.new(name: module_name, items: items, imports: imports)
      end

      def transform_type(type)
        with_current_node(type) do
          case type
          when AST::PrimType
            CoreIR::Builder.primitive_type(type.name)
          when AST::GenericType
            base_name = type.base_type.name
            validate_type_constraints(base_name, type.type_params)
            type_arg_names = type.type_params.map { |tp| transform_type(tp).name }.join(", ")
            CoreIR::Builder.primitive_type("#{base_name}<#{type_arg_names}>")
          when AST::RecordType
            fields = type.fields.map { |field| {name: field[:name], type: transform_type(field[:type])} }
            CoreIR::Builder.record_type(type.name, fields)
          when AST::SumType
            variants = type.variants.map do |variant|
              fields = variant[:fields].map { |field| {name: field[:name], type: transform_type(field[:type])} }
              {name: variant[:name], fields: fields}
            end
            CoreIR::Builder.sum_type(type.name, variants)
          when AST::ArrayType
            element_type = transform_type(type.element_type)
            CoreIR::ArrayType.new(element_type: element_type)
          else
            raise "Unknown type: #{type.class}"
          end
        end
      end

      def transform_type_decl(decl)
        with_current_node(decl) do
          type = transform_type(decl.type)

          type = case type
                 when CoreIR::RecordType
                   CoreIR::Builder.record_type(decl.name, type.fields)
                 when CoreIR::SumType
                   CoreIR::Builder.sum_type(decl.name, type.variants)
                 else
                   type
                 end
          register_sum_type_constructors(decl.name, type) if type.is_a?(CoreIR::SumType)
          type_params = normalize_type_params(decl.type_params)
          CoreIR::TypeDecl.new(name: decl.name, type: type, type_params: type_params)
        end
      end

      end
    end
  end
end
