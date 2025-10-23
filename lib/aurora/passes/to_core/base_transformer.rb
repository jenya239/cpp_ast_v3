# frozen_string_literal: true

module Aurora
  module Passes
    class ToCore
      # BaseTransformer
      # Shared utilities for transformation
      # Auto-extracted from to_core.rb during refactoring
      module BaseTransformer
      def builtin_function_info(name)
        case name
        when "sqrt"
          f32 = CoreIR::Builder.primitive_type("f32")
          FunctionInfo.new("sqrt", [f32], f32)
        else
          if IO_RETURN_TYPES.key?(name)
            FunctionInfo.new(name, [], io_return_type(name))
          else
            nil
          end
        end
      end

      def constructor_info_for(name, scrutinee_type)
        info = @sum_type_constructors[name]
        return unless info

        if scrutinee_type && type_name(info.ret_type) && type_name(scrutinee_type)
          return info if type_name(info.ret_type) == type_name(scrutinee_type)
        end

        info
      end

      def describe_type(type)
        normalized_type_name(type_name(type)) || "unknown"
      end

      def ensure_argument_count(member, args, expected)
        return if args.length == expected

        type_error("Method '#{member}' expects #{expected} argument(s), got #{args.length}")
      end

      def ensure_function_signature(func_decl)
        register_function_signature(func_decl)
        @function_table[func_decl.name]
      end

      def ensure_type!(type, message, node: nil)
        type_error(message, node: node) unless type
      end

      def extract_actual_type_name(type_node)
        case type_node
        when AST::PrimType
          name = type_node.name
          return nil if name.nil?
          return nil if name[0]&.match?(/[A-Z]/)
          name
        else
          nil
        end
      end

      def fresh_temp_name
        name = "__tmp#{@temp_counter}"
        @temp_counter += 1
        name
      end

      def function_placeholder_type(name)
        if (info = lookup_function_info(name))
          function_type_from_info(info)
        else
          CoreIR::Builder.function_type([], CoreIR::Builder.primitive_type("auto"))
        end
      end

      def function_type_from_info(info)
        params = info.param_types.each_with_index.map do |type, index|
          {name: "arg#{index}", type: type}
        end
        CoreIR::Builder.function_type(params, info.ret_type)
      end

      def generic_type_name?(name)
        name && name.match?(/\A[A-Z][A-Za-z0-9_]*\z/)
      end

      def io_return_type(name)
        case IO_RETURN_TYPES[name]
        when "i32"
          CoreIR::Builder.primitive_type("i32")
        when "string"
          CoreIR::Builder.primitive_type("string")
        when :array_of_string
          CoreIR::ArrayType.new(element_type: CoreIR::Builder.primitive_type("string"))
        else
          CoreIR::Builder.primitive_type("i32")
        end
      end

      def is_pure_expression(expr)
        case expr
        when CoreIR::LiteralExpr, CoreIR::VarExpr
          true
        when CoreIR::BinaryExpr
          is_pure_expression(expr.left) && is_pure_expression(expr.right)
        when CoreIR::UnaryExpr
          is_pure_expression(expr.operand)
        when CoreIR::CallExpr
          # Assume all calls are pure for now
          true
        when CoreIR::MemberExpr
          is_pure_expression(expr.object)
        when CoreIR::RecordExpr
          expr.fields.values.all? { |field| is_pure_expression(field) }
        when CoreIR::BlockExpr
          false
        else
          false
        end
      end

      def lookup_function_info(name)
        @function_table[name] || @sum_type_constructors[name] || builtin_function_info(name)
      end

      def normalize_type_params(params)
        params.map do |tp|
          with_current_node(tp) do
            name = tp.respond_to?(:name) ? tp.name : tp
            constraint = tp.respond_to?(:constraint) ? tp.constraint : nil
            validate_constraint_name(constraint)
            CoreIR::TypeParam.new(name: name, constraint: constraint)
          end
        end
      end

      def normalized_type_name(name)
        case name
        when "str"
          "string"
        else
          name
        end
      end

      def type_error(message, node: nil, origin: nil)
        origin ||= node&.origin
        origin ||= @current_node&.origin
        raise Aurora::CompileError.new(message, origin: origin)
      end

      def type_name(type)
        type&.name
      end

      def type_satisfies_constraint?(constraint, type_name)
        allowed = BUILTIN_CONSTRAINTS[constraint]
        allowed && allowed.include?(type_name)
      end

      def validate_constraint_name(name)
        return if name.nil? || name.empty?
        return if BUILTIN_CONSTRAINTS.key?(name)

        type_error("Unknown constraint '#{name}'")
      end

      def validate_function_call(info, args, name)
        expected = info.param_types || []
        return if expected.empty?

        if expected.length != args.length
          type_error("Function '#{name}' expects #{expected.length} argument(s), got #{args.length}")
        end

        expected.each_with_index do |type, index|
          ensure_compatible_type(args[index].type, type, "argument #{index + 1} of '#{name}'")
        end
      end

      def validate_type_constraints(base_name, actual_type_nodes)
        decl = @type_decl_table[base_name]
        return unless decl && decl.type_params.any?

        decl.type_params.zip(actual_type_nodes).each do |param_info, actual_node|
          next unless param_info.respond_to?(:constraint) && param_info.constraint && !param_info.constraint.empty?

          actual_name = extract_actual_type_name(actual_node)
          next if actual_name.nil?

          unless type_satisfies_constraint?(param_info.constraint, actual_name)
            type_error("Type '#{actual_name}' does not satisfy constraint '#{param_info.constraint}' for '#{param_info.name}'")
          end
        end
      end

      def with_current_node(node)
        previous = @current_node
        @current_node = node if node
        yield
      ensure
        @current_node = previous
      end

      end
    end
  end
end
