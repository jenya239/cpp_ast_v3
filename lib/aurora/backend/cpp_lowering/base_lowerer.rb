# frozen_string_literal: true

module Aurora
  module Backend
    class CppLowering
      # BaseLowerer
      # Base utilities for C++ code generation
      # Auto-extracted from cpp_lowering.rb during refactoring
      module BaseLowerer
      # Helper: Check if expression/type should be lowered as statement (not expression)
      def should_lower_as_statement?(expr_or_type)
        return true if expr_or_type.is_a?(CoreIR::UnitLiteral)
        return true if expr_or_type.is_a?(CoreIR::UnitType)
        return true if expr_or_type.is_a?(CoreIR::IfExpr) && expr_or_type.type.is_a?(CoreIR::UnitType)
        false
      end

      def map_type(type)
              case type
              when CoreIR::ArrayType
                "std::vector<#{map_type(type.element_type)}>"
              when CoreIR::OpaqueType
                # Opaque types: Check TypeRegistry first, or add pointer suffix
                if @type_registry && @type_registry.has_type?(type.name)
                  return @type_registry.cpp_name(type.name)
                end
                # Fallback: opaque types are pointers
                "#{type.name}*"
              when CoreIR::Type
                # NEW: Try TypeRegistry first for accurate C++ names
                if @type_registry && type.respond_to?(:name) && @type_registry.has_type?(type.name)
                  return @type_registry.cpp_name(type.name)
                end

                # OLD: Fallback to @type_map
                # Check if it's a known primitive type, otherwise treat as type parameter
                mapped = @type_map[type.name]
                if mapped
                  mapped
                elsif type.name =~ /^[A-Z][a-zA-Z0-9]*$/  # Uppercase name - likely type parameter
                  type.name  # Keep as-is (e.g., "T", "E", "Result")
                else
                  @type_map[type.name] || type.name
                end
              when CoreIR::RecordType
                # NEW: Try TypeRegistry first
                if @type_registry && @type_registry.has_type?(type.name)
                  return @type_registry.cpp_name(type.name)
                end

                # OLD: Fallback to @type_map
                @type_map[type.name] || type.name
              when CoreIR::SumType
                # NEW: Try TypeRegistry first
                if @type_registry && @type_registry.has_type?(type.name)
                  return @type_registry.cpp_name(type.name)
                end

                # OLD: Fallback to @type_map
                @type_map[type.name] || type.name
              when CoreIR::FunctionType
                "auto" # Simplified - real implementation would be more complex
              else
                "auto"
              end
            end

      def type_requires_auto?(type, type_str = nil)
              return true if type.nil?
      
              type_str ||= map_type(type)
              return true if type_str.nil? || type_str.empty?
              return true if type_str.include?("auto")
      
              case type
              when CoreIR::ArrayType
                type_requires_auto?(type.element_type)
              when CoreIR::FunctionType
                true
              when CoreIR::RecordType
                type.name.nil? || type.name.empty? || type.name == "record"
              when CoreIR::SumType
                type.name.nil? || type.name.empty?
              when CoreIR::Type
                name = type.name
                return false if name && @type_map.key?(name)
                name.nil? || name.empty? || name == "auto"
              else
                false
              end
            end

      def build_aurora_string(value)
              CppAst::Nodes::FunctionCallExpression.new(
                callee: CppAst::Nodes::Identifier.new(name: "aurora::String"),
                arguments: [cpp_string_literal(value)],
                argument_separators: []
              )
            end

      def cpp_string_literal(value)
              escaped = escape_cpp_string(value)
              CppAst::Nodes::StringLiteral.new(value: "\"#{escaped}\"")
            end

      def escape_cpp_string(value)
              value.each_char.map do |ch|
                case ch
                when "\\"
                  "\\\\"
                when "\""
                  "\\\""
                when "\n"
                  "\\n"
                when "\r"
                  "\\r"
                when "\t"
                  "\\t"
                when "\0"
                  "\\0"
                else
                  ch
                end
              end.join
            end

      def build_template_signature(type_params)
              params = type_params.map { |tp| "typename #{tp.name}" }.join(", ")
              requires_clause = build_requires_clause(type_params)
              params_suffix = requires_clause.empty? ? "\n" : "\nrequires #{requires_clause}\n"
              [params, params_suffix]
            end

      def build_requires_clause(type_params)
              clauses = type_params.map do |tp|
                next unless tp.constraint && !tp.constraint.empty?
                "#{tp.constraint}<#{tp.name}>"
              end.compact
              clauses.join(" && ")
            end

      def wrap_statements_with_template(type_params, program)
              # Wrap each statement (struct declarations, using) with template
              template_params_str, params_suffix = build_template_signature(type_params)
      
              wrapped_statements = program.statements.map do |stmt|
                CppAst::Nodes::TemplateDeclaration.new(
                  template_params: template_params_str,
                  declaration: stmt,
                  template_suffix: "",
                  less_suffix: "",
                  params_suffix: params_suffix
                )
              end
      
              CppAst::Nodes::Program.new(
                statements: wrapped_statements,
                statement_trailings: Array.new(wrapped_statements.size, "")
              )
            end

      end
    end
  end
end
