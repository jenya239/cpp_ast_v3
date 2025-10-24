# frozen_string_literal: true

module Aurora
  module Passes
    class ToCore
      # TypeInference
      # Type inference and type checking
      # Auto-extracted from to_core.rb during refactoring
      module TypeInference
      def combine_numeric_type(left_type, right_type)
        if type_name(left_type) == type_name(right_type)
          left_type
        elsif float_type?(left_type) || float_type?(right_type)
          CoreIR::Builder.primitive_type("f32")
        else
          type_error("Numeric operands must have matching types, got #{describe_type(left_type)} and #{describe_type(right_type)}")
        end
      end

      def ensure_boolean_type(type, context, node: nil)
        name = normalized_type_name(type_name(type))
        return if generic_type_name?(name)
        type_error("#{context} must be bool, got #{describe_type(type)}", node: node) unless name == "bool"
      end

      def ensure_compatible_type(actual, expected, context, node: nil)
        ensure_type!(actual, "#{context} has unknown type", node: node)
        ensure_type!(expected, "#{context} has unspecified expected type", node: node)

        actual_name = normalized_type_name(type_name(actual))
        expected_name = normalized_type_name(type_name(expected))

        return if expected_name.nil? || expected_name.empty?
        return if expected_name == "auto"
        return if generic_type_name?(expected_name)
        return if actual_name == "auto"
        return if actual_name == expected_name

        type_error("#{context} expected #{expected_name}, got #{actual_name}", node: node)
      end

      def ensure_numeric_type(type, context, node: nil)
        name = normalized_type_name(type_name(type))
        return if generic_type_name?(name)
        type_error("#{context} must be numeric, got #{describe_type(type)}", node: node) unless numeric_type?(type)
      end

      def float_type?(type)
        normalized_type_name(type_name(type)) == "f32"
      end

      def infer_binary_type(op, left_type, right_type)
        ensure_type!(left_type, "Left operand of '#{op}' has no type")
        ensure_type!(right_type, "Right operand of '#{op}' has no type")

        case op
        when "+"
          # Support both numeric addition and string concatenation
          if string_type?(left_type) && string_type?(right_type)
            CoreIR::Builder.primitive_type("string")
          elsif numeric_type?(left_type) && numeric_type?(right_type)
            combine_numeric_type(left_type, right_type)
          else
            type_error("Cannot add #{describe_type(left_type)} and #{describe_type(right_type)}")
          end
        when "-", "*", "%"
          ensure_numeric_type(left_type, "left operand of '#{op}'")
          ensure_numeric_type(right_type, "right operand of '#{op}'")
          combine_numeric_type(left_type, right_type)
        when "/"
          ensure_numeric_type(left_type, "left operand of '/' ")
          ensure_numeric_type(right_type, "right operand of '/' ")
          if float_type?(left_type) || float_type?(right_type)
            CoreIR::Builder.primitive_type("f32")
          else
            CoreIR::Builder.primitive_type("i32")
          end
        when "==", "!="
          ensure_compatible_type(left_type, right_type, "comparison '#{op}'")
          CoreIR::Builder.primitive_type("bool")
        when "<", ">", "<=", ">="
          ensure_numeric_type(left_type, "left operand of '#{op}'")
          ensure_numeric_type(right_type, "right operand of '#{op}'")
          CoreIR::Builder.primitive_type("bool")
        when "&&", "||"
          ensure_boolean_type(left_type, "left operand of '#{op}'")
          ensure_boolean_type(right_type, "right operand of '#{op}'")
          CoreIR::Builder.primitive_type("bool")
        else
          left_type
        end
      end

      def infer_call_type(callee, args)
        case callee
        when CoreIR::VarExpr
          if IO_RETURN_TYPES.key?(callee.name)
            return io_return_type(callee.name)
          end

          info = lookup_function_info(callee.name)
          unless info
            return CoreIR::Builder.primitive_type("auto")
          end
          validate_function_call(info, args, callee.name)
          info.ret_type
        when CoreIR::LambdaExpr
          function_type = callee.function_type
          expected = function_type.params || []

          if expected.length != args.length
            type_error("Lambda expects #{expected.length} argument(s), got #{args.length}")
          end

          expected.each_with_index do |param, index|
            ensure_compatible_type(args[index].type, param[:type], "lambda argument #{index + 1}")
          end

          function_type.ret_type
        when CoreIR::MemberExpr
          object_type = callee.object&.type
          type_error("Cannot call member on value without type") unless object_type

          member = callee.member

          if object_type.is_a?(CoreIR::ArrayType)
            case member
            when "length", "size"
              ensure_argument_count(member, args, 0)
              CoreIR::Builder.primitive_type("i32")
            when "is_empty"
              ensure_argument_count(member, args, 0)
              CoreIR::Builder.primitive_type("bool")
            when "map"
              ensure_argument_count(member, args, 1)
              element_type = lambda_return_type(args.first)
              type_error("Unable to infer return type of map lambda") unless element_type
              CoreIR::ArrayType.new(element_type: element_type)
            when "filter"
              ensure_argument_count(member, args, 1)
              CoreIR::ArrayType.new(element_type: object_type.element_type)
            when "fold"
              ensure_argument_count(member, args, 2)
              accumulator_type = args.first&.type
              ensure_type!(accumulator_type, "Unable to determine accumulator type for fold")
              accumulator_type
            else
              type_error("Unknown array method '#{member}'. Supported methods: length, size, is_empty, map, filter, fold")
            end
          elsif string_type?(object_type)
            case member
            when "split"
              ensure_argument_count(member, args, 1)
              CoreIR::ArrayType.new(element_type: CoreIR::Builder.primitive_type("string"))
            when "trim", "trim_start", "trim_end", "upper", "lower"
              ensure_argument_count(member, args, 0)
              CoreIR::Builder.primitive_type("string")
            when "is_empty"
              ensure_argument_count(member, args, 0)
              CoreIR::Builder.primitive_type("bool")
            when "length"
              ensure_argument_count(member, args, 0)
              CoreIR::Builder.primitive_type("i32")
            else
              type_error("Unknown string method '#{member}'. Supported methods: split, trim, trim_start, trim_end, upper, lower, is_empty, length")
            end
          elsif numeric_type?(object_type) && member == "sqrt"
            ensure_argument_count(member, args, 0)
            CoreIR::Builder.primitive_type("f32")
          else
            type_error("Unknown member '#{member}' for type #{describe_type(object_type)}")
          end
        else
          type_error("Cannot call value of type #{describe_type(callee.type)}")
        end
      end

      def infer_effects(body)
        # Simple effect inference
        effects = []

        # Check if function is pure (no side effects)
        if is_pure_expression(body)
          effects << :constexpr
        end

        effects << :noexcept

        effects
      end

      def infer_iterable_type(iterable_ir)
        if iterable_ir.type.is_a?(CoreIR::ArrayType)
          iterable_ir.type.element_type
        else
          type_error("Iterable expression must be an array, got #{describe_type(iterable_ir.type)}")
        end
      end

      def infer_member_type(object_type, member)
        type_error("Cannot access member '#{member}' on value without type") unless object_type

        # Try NEW TypeRegistry first for better type resolution
        if object_type.respond_to?(:name) && @type_registry.has_type?(object_type.name)
          member_type = @type_registry.resolve_member(object_type.name, member)
          return member_type if member_type
        end

        # Fallback to OLD type_table for backward compat
        if object_type.respond_to?(:name) && @type_table.key?(object_type.name)
          resolved_type = @type_table[object_type.name]
          # Recursively resolve with the actual type definition
          return infer_member_type(resolved_type, member) if resolved_type != object_type
        end

        if object_type.record?
          field = object_type.fields.find { |f| f[:name] == member }
          type_error("Unknown field '#{member}' for type #{object_type.name}") unless field
          field[:type]
        elsif object_type.is_a?(CoreIR::ArrayType)
          case member
          when "length", "size"
            CoreIR::Builder.primitive_type("i32")
          when "is_empty"
            CoreIR::Builder.primitive_type("bool")
          when "map", "filter", "fold"
            CoreIR::Builder.function_type([], CoreIR::Builder.primitive_type("auto"))
          else
            type_error("Unknown array member '#{member}'. Known members: length, size, is_empty, map, filter, fold")
          end
        elsif string_type?(object_type)
          case member
          when "split"
            CoreIR::ArrayType.new(element_type: CoreIR::Builder.primitive_type("string"))
          when "trim", "trim_start", "trim_end", "upper", "lower"
            CoreIR::Builder.primitive_type("string")
          when "is_empty"
            CoreIR::Builder.primitive_type("bool")
          when "length"
            CoreIR::Builder.primitive_type("i32")
          else
            type_error("Unknown string member '#{member}'. Known members: split, trim, trim_start, trim_end, upper, lower, is_empty, length")
          end
        elsif numeric_type?(object_type) && member == "sqrt"
          f32 = CoreIR::Builder.primitive_type("f32")
          CoreIR::Builder.function_type([], f32)
        else
          type_error("Unknown member '#{member}' for type #{describe_type(object_type)}")
        end
      end

      def infer_type(name)
        return @var_types[name] if @var_types.key?(name)

        if (info = lookup_function_info(name))
          return function_type_from_info(info)
        end

        return CoreIR::Builder.primitive_type("bool") if %w[true false].include?(name)

        scope = @var_types.keys.sort.join(", ")
        type_error("Unknown identifier '#{name}' (in scope: #{scope})")
      end

      def infer_unary_type(op, operand_type)
        ensure_type!(operand_type, "Unary operand for '#{op}' has no type")

        case op
        when "!"
          ensure_boolean_type(operand_type, "operand of '!'")
          CoreIR::Builder.primitive_type("bool")
        when "-", "+"
          ensure_numeric_type(operand_type, "operand of '#{op}'")
          operand_type
        else
          operand_type
        end
      end

      def numeric_type?(type)
        type_str = normalized_type_name(type_name(type))
        return true if NUMERIC_PRIMITIVES.include?(type_str)

        # Check if this is a generic type parameter with Numeric constraint
        type_param = @current_type_params.find { |tp| tp.name == type_str }
        type_param && type_param.constraint == "Numeric"
      end

      def string_type?(type)
        %w[string str].include?(normalized_type_name(type_name(type)))
      end

      def void_type?(type)
        normalized_type_name(type_name(type)) == "void"
      end

      end
    end
  end
end
