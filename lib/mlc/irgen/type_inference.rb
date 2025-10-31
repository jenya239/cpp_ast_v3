# frozen_string_literal: true

module MLC
  class IRGen
      # TypeInference
      # Type inference and type checking
      # Auto-extracted from to_core.rb during refactoring
      module TypeInference
      def combine_numeric_type(left_type, right_type)
        # If both are type variables, preserve the shared variable when possible
        if left_type.is_a?(HighIR::TypeVariable) && right_type.is_a?(HighIR::TypeVariable)
          return left_type if left_type.name == right_type.name
          return HighIR::Builder.primitive_type("i32")
        end

        # If one is a type variable, return the concrete type
        return right_type if left_type.is_a?(HighIR::TypeVariable)
        return left_type if right_type.is_a?(HighIR::TypeVariable)

        if type_name(left_type) == type_name(right_type)
          left_type
        elsif float_type?(left_type) || float_type?(right_type)
          HighIR::Builder.primitive_type("f32")
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
        return if expected.is_a?(HighIR::TypeVariable)
        return if actual_name == expected_name

        @event_bus&.publish(
          :type_mismatch,
          context: context,
          actual: actual_name,
          expected: expected_name,
          origin: node&.origin || @current_node&.origin
        )

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
            HighIR::Builder.primitive_type("string")
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
            HighIR::Builder.primitive_type("f32")
          else
            HighIR::Builder.primitive_type("i32")
          end
        when "==", "!="
          ensure_compatible_type(left_type, right_type, "comparison '#{op}'")
          HighIR::Builder.primitive_type("bool")
        when "<", ">", "<=", ">="
          ensure_numeric_type(left_type, "left operand of '#{op}'")
          ensure_numeric_type(right_type, "right operand of '#{op}'")
          HighIR::Builder.primitive_type("bool")
        when "&&", "||"
          ensure_boolean_type(left_type, "left operand of '#{op}'")
          ensure_boolean_type(right_type, "right operand of '#{op}'")
          HighIR::Builder.primitive_type("bool")
        else
          left_type
        end
      end

      def infer_call_type(callee, args)
        case callee
        when HighIR::VarExpr
          if IO_RETURN_TYPES.key?(callee.name)
            return io_return_type(callee.name)
          end

          info = lookup_function_info(callee.name)
          unless info
            return HighIR::Builder.primitive_type("auto")
          end

          # Check if this is a generic function
          if info.type_params && !info.type_params.empty?
            instantiation = instantiate_signature(info, args, callee.name)
            instantiation.ret_type
          else
            # Non-generic function - use original logic
            validate_function_call(info, args, callee.name)
            info.ret_type
          end
        when HighIR::LambdaExpr
          function_type = callee.function_type
          expected = function_type.params || []

          if expected.length != args.length
            type_error("Lambda expects #{expected.length} argument(s), got #{args.length}")
          end

          expected.each_with_index do |param, index|
            ensure_compatible_type(args[index].type, param[:type], "lambda argument #{index + 1}")
          end

          function_type.ret_type
        when HighIR::MemberExpr
          member = callee.member

          if callee.object.is_a?(HighIR::VarExpr)
            if (info = module_member_info(callee.object.name, member))
              validate_function_call(info, args, member)
              return info.ret_type
            end
          end

          object_type = callee.object&.type
          type_error("Cannot call member on value without type") unless object_type

          if object_type.is_a?(HighIR::ArrayType)
            case member
            when "length", "size"
              ensure_argument_count(member, args, 0)
              HighIR::Builder.primitive_type("i32")
            when "is_empty"
              ensure_argument_count(member, args, 0)
              HighIR::Builder.primitive_type("bool")
            when "map"
              ensure_argument_count(member, args, 1)
              element_type = lambda_return_type(args.first)
              type_error("Unable to infer return type of map lambda") unless element_type
              HighIR::ArrayType.new(element_type: element_type)
            when "filter"
              ensure_argument_count(member, args, 1)
              HighIR::ArrayType.new(element_type: object_type.element_type)
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
              HighIR::ArrayType.new(element_type: HighIR::Builder.primitive_type("string"))
            when "trim", "trim_start", "trim_end", "upper", "lower"
              ensure_argument_count(member, args, 0)
              HighIR::Builder.primitive_type("string")
            when "is_empty"
              ensure_argument_count(member, args, 0)
              HighIR::Builder.primitive_type("bool")
            when "length"
              ensure_argument_count(member, args, 0)
              HighIR::Builder.primitive_type("i32")
            else
              type_error("Unknown string method '#{member}'. Supported methods: split, trim, trim_start, trim_end, upper, lower, is_empty, length")
            end
          elsif numeric_type?(object_type) && member == "sqrt"
            ensure_argument_count(member, args, 0)
            HighIR::Builder.primitive_type("f32")
          else
            type_error("Unknown member '#{member}' for type #{describe_type(object_type)}", node: node)
          end
        else
          type_error("Cannot call value of type #{describe_type(callee.type)}")
        end
      end

      def infer_iterable_type(iterable_ir, node: nil)
        if iterable_ir.type.is_a?(HighIR::ArrayType)
          iterable_ir.type.element_type
        else
          type_error("Iterable expression must be an array, got #{describe_type(iterable_ir.type)}", node: node)
        end
      end

      def instantiate_signature(info, args, name = nil)
        @generic_call_resolver.instantiate(info, args, name: name || info.name)
      end

      def infer_member_type(object_type, member, node: nil)
        type_error("Cannot access member '#{member}' on value without type", node: node) unless object_type

        if object_type.is_a?(HighIR::GenericType)
          base_name = type_name(object_type.base_type)

          if base_name && @type_registry.has_type?(base_name)
            base_member_type = @type_registry.resolve_member(base_name, member)
            if base_member_type
              instantiated = instantiate_generic_member_type(base_name, base_member_type, object_type.type_args)
              return instantiated if instantiated
            end
          end
        end

        if object_type.respond_to?(:name) && @type_registry.has_type?(object_type.name)
          member_type = @type_registry.resolve_member(object_type.name, member)
          return member_type if member_type

          resolved_type = @type_registry.lookup(object_type.name)&.core_ir_type
          if resolved_type && resolved_type != object_type
            return infer_member_type(resolved_type, member)
          end
        end

        if object_type.record?
          field = object_type.fields.find { |f| f[:name] == member }
          type_error("Unknown field '#{member}' for type #{object_type.name}", node: node) unless field
          field[:type]
        elsif object_type.is_a?(HighIR::ArrayType)
          case member
          when "length", "size"
            HighIR::Builder.primitive_type("i32")
          when "is_empty"
            HighIR::Builder.primitive_type("bool")
          when "map", "filter", "fold"
            HighIR::Builder.function_type([], HighIR::Builder.primitive_type("auto"))
          else
            type_error("Unknown array member '#{member}'. Known members: length, size, is_empty, map, filter, fold", node: node)
          end
        elsif string_type?(object_type)
          case member
          when "split"
            HighIR::ArrayType.new(element_type: HighIR::Builder.primitive_type("string"))
          when "trim", "trim_start", "trim_end", "upper", "lower"
            HighIR::Builder.primitive_type("string")
          when "is_empty"
            HighIR::Builder.primitive_type("bool")
          when "length"
            HighIR::Builder.primitive_type("i32")
          else
            type_error("Unknown string member '#{member}'. Known members: split, trim, trim_start, trim_end, upper, lower, is_empty, length", node: node)
          end
        elsif numeric_type?(object_type) && member == "sqrt"
          f32 = HighIR::Builder.primitive_type("f32")
          HighIR::Builder.function_type([], f32)
        else
          type_error("Unknown member '#{member}' for type #{describe_type(object_type)}", node: node)
        end
      end

      def infer_type(name)
        return @var_types[name] if @var_types.key?(name)

        if (info = lookup_function_info(name))
          return function_type_from_info(info)
        end

        return HighIR::Builder.primitive_type("bool") if %w[true false].include?(name)

        scope = @var_types.keys.sort.join(", ")
        type_error("Unknown identifier '#{name}' (in scope: #{scope})")
      end

      def infer_unary_type(op, operand_type)
        ensure_type!(operand_type, "Unary operand for '#{op}' has no type")

        case op
        when "!"
          ensure_boolean_type(operand_type, "operand of '!'")
          HighIR::Builder.primitive_type("bool")
        when "-", "+"
          ensure_numeric_type(operand_type, "operand of '#{op}'")
          operand_type
        else
          operand_type
        end
      end

      def numeric_type?(type)
        # TypeVariable is assumed to be numeric-compatible (no constraints yet)
        return true if type.is_a?(HighIR::TypeVariable)

        type_str = normalized_type_name(type_name(type))
        return true if NUMERIC_PRIMITIVES.include?(type_str)

        # Check if this is a generic type parameter with Numeric constraint
        type_param = current_type_params.find { |tp| tp.name == type_str }
        type_param && type_param.constraint == "Numeric"
      end

      def string_type?(type)
        %w[string str].include?(normalized_type_name(type_name(type)))
      end

      def void_type?(type)
        return true if type.is_a?(HighIR::UnitType)
        normalized_type_name(type_name(type)) == "void"
      end

      # Generic type inference: infer concrete types for type parameters
      # Returns a hash mapping type parameter names to concrete types
      def infer_type_arguments(type_params, param_types, arg_types)
        type_map = {}

        param_types.each_with_index do |param_type, index|
          arg_type = arg_types[index]
          next unless arg_type

          unify_types(param_type, arg_type, type_map)
        end

        type_map
      end

      # Unify two types to infer type variable bindings
      # Mutates type_map to add discovered bindings
      def unify_types(pattern_type, concrete_type, type_map)
        case pattern_type
        when HighIR::TypeVariable
          # This is a type variable - bind it to the concrete type
          var_name = pattern_type.name
          if type_map.key?(var_name)
            # Already bound - verify consistency
            existing = type_map[var_name]
            if existing.is_a?(HighIR::TypeVariable)
              type_map[var_name] = concrete_type
            elsif concrete_type.is_a?(HighIR::TypeVariable)
              # keep existing concrete binding
            elsif normalized_type_name(type_name(existing)) == normalized_type_name(type_name(concrete_type))
              type_map[var_name] = concrete_type
            elsif !types_compatible?(existing, concrete_type)
              type_error("Type variable #{var_name} bound to both #{describe_type(existing)} and #{describe_type(concrete_type)}")
            end
          else
            # New binding
            type_map[var_name] = concrete_type
          end

        when HighIR::GenericType
          # Both should be generic with same base and compatible args
          if concrete_type.is_a?(HighIR::GenericType)
            unify_types(pattern_type.base_type, concrete_type.base_type, type_map)
            pattern_type.type_args.each_with_index do |pattern_arg, index|
              concrete_arg = concrete_type.type_args[index]
              unify_types(pattern_arg, concrete_arg, type_map) if concrete_arg
            end
          end

        when HighIR::ArrayType
          # Array types - unify element types
          if concrete_type.is_a?(HighIR::ArrayType)
            unify_types(pattern_type.element_type, concrete_type.element_type, type_map)
          end

        when HighIR::FunctionType
          # Function types - unify parameters and return types
          if concrete_type.is_a?(HighIR::FunctionType)
            pattern_type.params.each_with_index do |pattern_param, index|
              concrete_param = concrete_type.params[index]
              unify_types(pattern_param[:type], concrete_param[:type], type_map) if concrete_param
            end
            unify_types(pattern_type.ret_type, concrete_type.ret_type, type_map)
          end

        else
          # Primitive types, record types, etc. - just verify they match
          # No unification needed
        end
      end

      # Substitute type variables with concrete types
      def substitute_type(type, type_map)
        case type
        when HighIR::TypeVariable
          # Replace type variable with its binding
          type_map[type.name] || type

        when HighIR::GenericType
          # Recursively substitute in base type and type arguments
          new_base = substitute_type(type.base_type, type_map)
          new_args = type.type_args.map { |arg| substitute_type(arg, type_map) }
          if new_base != type.base_type || new_args != type.type_args
            HighIR::Builder.generic_type(new_base, new_args)
          else
            type
          end

        when HighIR::ArrayType
          # Substitute in element type
          new_element = substitute_type(type.element_type, type_map)
          new_element != type.element_type ? HighIR::Builder.array_type(new_element) : type

        when HighIR::FunctionType
          # Substitute in parameters and return type
          new_params = type.params.map do |p|
            new_type = substitute_type(p[:type], type_map)
            new_type != p[:type] ? {name: p[:name], type: new_type} : p
          end
          new_ret = substitute_type(type.ret_type, type_map)
          (new_params != type.params || new_ret != type.ret_type) ? HighIR::Builder.function_type(new_params, new_ret) : type

        else
          # Primitive types, record types, etc. - no substitution needed
          type
        end
      end

      # Check if two types are compatible (for type variable binding verification)
      def types_compatible?(type1, type2)
        return true if type1 == type2

        name1 = type_name(type1)
        name2 = type_name(type2)

        return true if name1 == name2

        # Allow some flexibility for numeric types
        if numeric_type?(type1) && numeric_type?(type2)
          return true
        end

        false
      end

      def instantiate_generic_member_type(base_name, member_type, type_args)
        type_decl = @type_decl_table[base_name]
        return member_type unless type_decl && type_decl.type_params.any?

        type_map = {}
        type_decl.type_params.each_with_index do |tp, index|
          actual = type_args[index]
          next unless actual
          type_map[tp.name] = actual
        end

        substitute_type(member_type, type_map)
      end

      end
  end
end
