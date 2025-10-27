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
            refresh_type_reference(type, resolved_name, resolved)
          end
          info.ret_type = refresh_type_reference(info.ret_type, resolved_name, resolved)
        end
      end

      # Recursively refresh type references, preserving GenericType structure
      def refresh_type_reference(type, resolved_name, resolved_type)
        case type
        when CoreIR::GenericType
          # Don't replace the entire GenericType, just refresh its base_type
          base_type = refresh_type_reference(type.base_type, resolved_name, resolved_type)
          type_args = type.type_args.map { |arg| refresh_type_reference(arg, resolved_name, resolved_type) }
          if base_type != type.base_type || type_args != type.type_args
            CoreIR::Builder.generic_type(base_type, type_args)
          else
            type
          end
        when CoreIR::ArrayType
          # Refresh element type
          element_type = refresh_type_reference(type.element_type, resolved_name, resolved_type)
          element_type != type.element_type ? CoreIR::Builder.array_type(element_type) : type
        when CoreIR::FunctionType
          # Refresh params and return type
          params = type.params.map { |p| {name: p[:name], type: refresh_type_reference(p[:type], resolved_name, resolved_type)} }
          ret_type = refresh_type_reference(type.ret_type, resolved_name, resolved_type)
          (params != type.params || ret_type != type.ret_type) ? CoreIR::Builder.function_type(params, ret_type) : type
        else
          # For primitive types and others, replace if name matches
          type_name(type) == resolved_name ? resolved_type : type
        end
      end

      def register_function_signature(func_decl)
        if @function_table.key?(func_decl.name)
          return @function_table[func_decl.name]
        end

        # Set type parameters context before transforming types
        type_params = normalize_type_params(func_decl.type_params)

        info = nil
        with_type_params(type_params) do
          param_types = func_decl.params.map { |param| transform_type(param.type) }
          ret_type = transform_type(func_decl.ret_type)
          info = FunctionInfo.new(func_decl.name, param_types, ret_type, type_params)
          @function_table[func_decl.name] = info
        end

        info
      end

      def register_stdlib_imports(import_decl)
        return unless @stdlib_resolver.stdlib_module?(import_decl.path)

        @rule_engine.apply(
          :core_ir_stdlib_import,
          import_decl,
          context: {
            stdlib_registry: @stdlib_registry,
            register_stdlib_function: method(:register_stdlib_function_metadata),
            register_stdlib_type: method(:register_stdlib_type_metadata),
            on_missing_item: lambda do |name, origin|
              import_origin = origin || import_decl.origin
              @event_bus.publish(
                :stdlib_missing_item,
                module: import_decl.path,
                item: name,
                origin: import_origin
              )
              type_error("Unknown item '#{name}' in stdlib import '#{import_decl.path}'", node: import_decl, origin: import_origin)
            end,
            event_bus: @event_bus
          }
        )
      end

      def register_stdlib_function_metadata(decl)
        return if @function_table.key?(decl.name)

        type_params = normalize_type_params(decl.type_params)

        with_current_node(decl) do
          with_type_params(type_params) do
            param_types = decl.params.map { |param| transform_type(param.type) }
            ret_type = transform_type(decl.ret_type)
            @function_table[decl.name] = FunctionInfo.new(decl.name, param_types, ret_type, type_params)
          end
        end
      end

      def register_stdlib_type_metadata(decl, namespace)
        return if @type_decl_table.key?(decl.name)

        type_decl_ir = build_type_decl_for_import(decl)

        kind = infer_type_kind(decl, type_decl_ir.type)
        @type_registry.register(
          decl.name,
          ast_node: decl,
          core_ir_type: type_decl_ir.type,
          namespace: namespace,
          kind: kind,
          exported: decl.exported
        )

        @type_table[decl.name] = type_decl_ir.type
        @type_decl_table[decl.name] = decl
        register_sum_type_constructors(decl.name, type_decl_ir.type) if type_decl_ir.type.is_a?(CoreIR::SumType)
      end

      def build_type_decl_for_import(decl)
        type_params = normalize_type_params(decl.type_params)

        type = nil

        with_current_node(decl) do
          with_type_params(type_params) do
            type = transform_type(decl.type)

            type = case type
                   when CoreIR::RecordType
                     CoreIR::Builder.record_type(decl.name, type.fields)
                   when CoreIR::SumType
                     CoreIR::Builder.sum_type(decl.name, type.variants)
                   else
                     type
                   end
          end
        end

        CoreIR::TypeDecl.new(name: decl.name, type: type, type_params: type_params)
      end

      def register_sum_type_constructors(sum_type_name, sum_type)
        return unless sum_type.respond_to?(:variants)

        type_decl = @type_decl_table[sum_type_name]
        type_params = type_decl ? normalize_type_params(type_decl.type_params) : []

        type_param_vars = type_params.map do |tp|
          CoreIR::Builder.type_variable(tp.name, constraint: tp.constraint)
        end
        generic_ret_type = if type_param_vars.any?
          CoreIR::Builder.generic_type(sum_type, type_param_vars)
        else
          sum_type
        end

        sum_type.variants.each do |variant|
          field_types = (variant[:fields] || []).map { |field| field[:type] }
          @sum_type_constructors[variant[:name]] = FunctionInfo.new(variant[:name], field_types, generic_ret_type, type_params)
        end
      end

      # Helper: Infer type kind from AST and CoreIR
      # @param ast_decl [AST::TypeDecl] AST type declaration
      # @param core_ir_type [CoreIR::Type] CoreIR type
      # @return [Symbol] :primitive, :record, :sum, :opaque
      def infer_type_kind(ast_decl, core_ir_type)
        # Check if it's an opaque type (explicit AST::OpaqueType or old-style implicit)
        if core_ir_type.is_a?(CoreIR::OpaqueType) || ast_decl.type.is_a?(AST::OpaqueType)
          return :opaque
        end

        # Legacy: Check if it's an old-style opaque type (PrimType with same name as decl)
        # This handles types declared before AST::OpaqueType was introduced
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
          # Normalize and set type params FIRST, before transforming any types
          type_params = normalize_type_params(func.type_params)
          with_type_params(type_params) do
            signature = ensure_function_signature(func)
            param_types = signature.param_types

            if param_types.length != func.params.length
              type_error("Function '#{func.name}' expects #{param_types.length} parameter(s), got #{func.params.length}")
            end

            params = func.params.each_with_index.map do |param, index|
              CoreIR::Param.new(name: param.name, type: param_types[index])
            end

            ret_type = signature.ret_type

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
            result_func = nil

            with_function_return(ret_type) do
              params.each do |param|
                @var_types[param.name] = param.type
              end

              body = transform_expression(func.body)

              unless void_type?(ret_type)
                ensure_compatible_type(body.type, ret_type, "function '#{func.name}' result")
              else
                type_error("function '#{func.name}' should not return a value") unless void_type?(body.type)
              end

              result_func = CoreIR::Func.new(
                name: func.name,
                params: params,
                ret_type: ret_type,
                body: body,
                effects: [],
                type_params: type_params
              )
            end

            result_func = @rule_engine.apply(
              :core_ir_function,
              result_func,
              context: {
                type_context: @type_context,
                type_registry: @type_registry,
                effect_analyzer: @effect_analyzer
              }
            )

            @var_types = saved_var_types
            result_func
          end
        end
      end

      def transform_program(program)
        context = {
          program: program,
          imports: [],
          type_items: [],
          func_items: [],
          module_name: program.module_decl ? program.module_decl.name : "main"
        }

        build_program_pass_manager.run(context)

        items = context[:type_items] + context[:func_items]

        CoreIR::Module.new(
          name: context[:module_name],
          items: items,
          imports: context[:imports]
        )
      end

      def build_program_pass_manager
        Aurora::Passes::PassManager.new.tap do |manager|
          manager.register(:collect_imports, method(:pass_collect_imports))
          manager.register(:preregister_types, method(:pass_preregister_types))
          manager.register(:preregister_functions, method(:pass_preregister_functions))
          manager.register(:lower_declarations, method(:pass_lower_declarations))
        end
      end

      def pass_collect_imports(context)
        program = context[:program]

        program.imports.each do |import_decl|
          context[:imports] << CoreIR::Import.new(
            path: import_decl.path,
            items: import_decl.items
          )

          register_stdlib_imports(import_decl)
        end
      end

      def pass_preregister_types(context)
        program = context[:program]

        program.declarations.each do |decl|
          next unless decl.is_a?(AST::TypeDecl)
          @type_decl_table[decl.name] = decl
        end
      end

      def pass_preregister_functions(context)
        program = context[:program]

        program.declarations.each do |decl|
          register_function_signature(decl) if decl.is_a?(AST::FuncDecl)
        end
      end

      def pass_lower_declarations(context)
        program = context[:program]

        program.declarations.each do |decl|
          case decl
          when AST::TypeDecl
            type_decl = transform_type_decl(decl)
            context[:type_items] << type_decl
            @type_table[decl.name] = type_decl.type
            refresh_function_signatures!(decl.name)
          when AST::FuncDecl
            context[:func_items] << transform_function(decl)
          end
        end
      end

      def transform_type(type)
        with_current_node(type) do
          case type
          when AST::PrimType
            # Check if this is a reference to a type parameter
            if current_type_params.any? { |tp| tp.name == type.name }
              # This is a type variable (reference to type parameter)
              constraint_param = current_type_params.find { |tp| tp.name == type.name }
              CoreIR::Builder.type_variable(type.name, constraint: constraint_param&.constraint)
            else
              CoreIR::Builder.primitive_type(type.name)
            end
          when AST::OpaqueType
            CoreIR::Builder.opaque_type(type.name)
          when AST::GenericType
            # Validate generic constraints before lowering
            base_name = type.base_type.respond_to?(:name) ? type.base_type.name : nil
            validate_type_constraints(base_name, type.type_params) if base_name

            # Transform to CoreIR::GenericType with proper type arguments
            base_type = transform_type(type.base_type)
            type_args = type.type_params.map { |tp| transform_type(tp) }
            CoreIR::Builder.generic_type(base_type, type_args)
          when AST::FunctionType
            # Transform function type: fn(T, U) -> V
            param_types = type.param_types.map { |pt| transform_type(pt) }
            ret_type = transform_type(type.ret_type)

            # Convert to params format expected by CoreIR::FunctionType
            params = param_types.map.with_index { |pt, i| {name: "arg#{i}", type: pt} }
            CoreIR::Builder.function_type(params, ret_type)
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
            CoreIR::Builder.array_type(element_type)
          else
            raise "Unknown type: #{type.class}"
          end
        end
      end

      def transform_type_decl(decl)
        with_current_node(decl) do
          # Normalize type params first
          type_params = normalize_type_params(decl.type_params)

          type = nil

          with_type_params(type_params) do
            # Transform the type definition
            type = transform_type(decl.type)

            type = case type
                   when CoreIR::RecordType
                     CoreIR::Builder.record_type(decl.name, type.fields)
                   when CoreIR::SumType
                     CoreIR::Builder.sum_type(decl.name, type.variants)
                   else
                     type
                   end

            # Register type in TypeRegistry
            kind = infer_type_kind(decl, type)
            @type_registry.register(
              decl.name,
              ast_node: decl,
              core_ir_type: type,
              namespace: nil,  # Main module types have no namespace
              kind: kind,
              exported: decl.exported
            )
          end

          # Create TypeDecl
          type_decl = CoreIR::TypeDecl.new(name: decl.name, type: type, type_params: type_params)

          # Backward compatibility: register TypeDecl in old @type_table (not just type)
          @type_table[decl.name] = type_decl

          @rule_engine.apply(
            :core_ir_type_decl,
            type_decl,
            context: {
              type: type,
              source_decl: decl,
              type_registry: @type_registry,
              register_sum_type_constructors: method(:register_sum_type_constructors)
            }
          )

          type_decl
        end
      end

      end
    end
  end
end
