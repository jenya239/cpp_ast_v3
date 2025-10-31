# frozen_string_literal: true

module MLC
  module Backend
    # Pure helper functions for C++ code generation
    # All functions are stateless and testable independently
    module CodeGenHelpers
        CPP_KEYWORDS = %w[
          alignas alignof and and_eq asm atomic_cancel atomic_commit atomic_noexcept auto bitand
          bitor bool break case catch char char8_t char16_t char32_t class compl concept const
          consteval constexpr constinit const_cast continue co_await co_return co_yield
          decltype default delete do double dynamic_cast else enum explicit export extern false
          float for friend goto if import inline int long module mutable namespace new noexcept
          not not_eq nullptr operator or or_eq private protected public register reinterpret_cast
          requires return short signed sizeof static static_assert static_cast struct switch
          template this thread_local throw true try typedef typeid typename union unsigned using
          virtual void volatile wchar_t while xor xor_eq
        ].freeze

        module_function

        # Check if name is a C++ keyword
        def cpp_keyword?(name)
          CPP_KEYWORDS.include?(name)
        end

        # Sanitize identifier for C++ (add _ suffix if keyword)
        # Pure function version - returns sanitized name without memoization
        def sanitize_identifier(name)
          return name unless name.is_a?(String)
          cpp_keyword?(name) ? "#{name}_" : name
        end

        # Escape string for C++ string literals
        def escape_cpp_string(value)
          value.each_char.map do |ch|
            case ch
            when "\\" then "\\\\"
            when "\"" then "\\\""
            when "\n" then "\\n"
            when "\r" then "\\r"
            when "\t" then "\\t"
            when "\0" then "\\0"
            else ch
            end
          end.join
        end

        # Build C++ string literal node
        def cpp_string_literal(value)
          escaped = escape_cpp_string(value)
          CppAst::Nodes::StringLiteral.new(value: "\"#{escaped}\"")
        end

        # Build mlc::String(...) call
        def build_aurora_string(value)
          CppAst::Nodes::FunctionCallExpression.new(
            callee: CppAst::Nodes::Identifier.new(name: "mlc::String"),
            arguments: [cpp_string_literal(value)],
            argument_separators: []
          )
        end

        # Get qualified function name from registry
        # Returns nil if not found
        def qualified_function_name(name, function_registry)
          return nil unless function_registry

          entry = function_registry.fetch_entry(name)
          return nil unless entry

          base_name = sanitize_identifier(entry.name)
          namespace = entry.namespace

          if namespace && !namespace.empty?
            "#{namespace}::#{base_name}"
          else
            base_name
          end
        end

        # Map HighIR type to C++ type string
        # Pure function - all dependencies passed as parameters
        def map_type(type, type_map:, type_registry: nil)
          case type
          when HighIR::TypeVariable
            # Type variables map directly to their name (T, U, E, etc.)
            type.name

          when HighIR::GenericType
            # Generic types: Base<Arg1, Arg2, ...>
            base_name = map_type(type.base_type, type_map: type_map, type_registry: type_registry)
            type_args = type.type_args.map { |arg|
              map_type(arg, type_map: type_map, type_registry: type_registry)
            }.join(", ")
            "#{base_name}<#{type_args}>"

          when HighIR::ArrayType
            element_type = map_type(type.element_type, type_map: type_map, type_registry: type_registry)
            "std::vector<#{element_type}>"

          when HighIR::FunctionType
            # Function types: std::function<ReturnType(Arg1, Arg2, ...)>
            param_types = type.params.map { |p|
              map_type(p[:type], type_map: type_map, type_registry: type_registry)
            }.join(", ")
            ret_type = map_type(type.ret_type, type_map: type_map, type_registry: type_registry)
            "std::function<#{ret_type}(#{param_types})>"

          when HighIR::OpaqueType
            # Check TypeRegistry first
            if type_registry && type_registry.has_type?(type.name)
              return type_registry.cpp_name(type.name)
            end
            # Fallback: opaque types are pointers
            "#{type.name}*"

          when HighIR::RecordType, HighIR::SumType
            # Try TypeRegistry first
            if type_registry && type_registry.has_type?(type.name)
              return type_registry.cpp_name(type.name)
            end
            # Fallback to type_map
            type_map[type.name] || type.name

          when HighIR::Type
            # Try TypeRegistry first
            if type_registry && type.respond_to?(:name) && type_registry.has_type?(type.name)
              return type_registry.cpp_name(type.name)
            end

            # Check if it's a known primitive type
            mapped = type_map[type.name]
            return mapped if mapped

            # Uppercase name - likely type parameter (T, E, Result)
            return type.name if type.name =~ /^[A-Z][a-zA-Z0-9]*$/

            # Fallback
            type_map[type.name] || type.name

          else
            "auto"
          end
        end

        # Check if type requires 'auto' instead of explicit type
        def type_requires_auto?(type, type_map:, type_registry: nil, type_str: nil)
          return true if type.nil?

          type_str ||= map_type(type, type_map: type_map, type_registry: type_registry)
          return true if type_str.nil? || type_str.empty?
          return true if type_str.include?("auto")

          case type
          when HighIR::ArrayType
            type_requires_auto?(type.element_type, type_map: type_map, type_registry: type_registry)
          when HighIR::FunctionType
            true
          when HighIR::RecordType
            type.name.nil? || type.name.empty? || type.name == "record"
          when HighIR::SumType
            type.name.nil? || type.name.empty?
          when HighIR::Type
            name = type.name
            return false if name && type_map.key?(name)
            name.nil? || name.empty? || name == "auto"
          else
            false
          end
        end

        # Build template signature for generics
        def build_template_signature(type_params)
          params = type_params.map { |tp| "typename #{tp.name}" }.join(", ")
          requires_clause = build_requires_clause(type_params)
          params_suffix = requires_clause.empty? ? "\n" : "\nrequires #{requires_clause}\n"
          [params, params_suffix]
        end

        # Build C++20 requires clause for type constraints
        def build_requires_clause(type_params)
          clauses = type_params.map do |tp|
            next unless tp.constraint && !tp.constraint.empty?
            "#{tp.constraint}<#{tp.name}>"
          end.compact
          clauses.join(" && ")
        end

      # Check if expression/type should be lowered as statement (not expression)
      def should_lower_as_statement?(expr_or_type)
        return true if expr_or_type.is_a?(HighIR::UnitLiteral)
        return true if expr_or_type.is_a?(HighIR::UnitType)
        return true if expr_or_type.is_a?(HighIR::IfExpr) && expr_or_type.type.is_a?(HighIR::UnitType)
        false
      end
    end
  end
end
