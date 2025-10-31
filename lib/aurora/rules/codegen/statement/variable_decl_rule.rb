# frozen_string_literal: true

require_relative "../../base_rule"
require_relative "../../../backend/cpp_lowering/helpers"

module Aurora
  module Rules
    module CodeGen
      module Statement
        # Rule for lowering CoreIR variable declarations to C++ variable declarations
        class VariableDeclRule < BaseRule
          include Aurora::Backend::CppLoweringHelpers

          def applies?(node, _context = {})
            node.is_a?(Aurora::CoreIR::VariableDeclStmt)
          end

          def apply(node, context = {})
            lowerer = context[:lowerer]

            # Map type to C++ (using lowerer's map_type which has access to @type_map and @type_registry)
            type_str = lowerer.send(:map_type, node.type)
            use_auto = lowerer.send(:type_requires_auto?, node.type, type_str)

            # Lower initializer expression
            init_expr = lowerer.send(:lower_expression, node.value)

            # Build declarator
            decl_type = use_auto ? "auto" : type_str
            identifier = sanitize_identifier(node.name)
            declarator = "#{identifier} = #{init_expr.to_source}"

            # Don't add const for pointer types (they end with *)
            is_pointer = type_str.end_with?("*")
            prefix = (node.mutable || is_pointer) ? "" : "const "

            CppAst::Nodes::VariableDeclaration.new(
              type: decl_type,
              declarators: [declarator],
              declarator_separators: [],
              type_suffix: " ",
              prefix_modifiers: prefix
            )
          end
        end
      end
    end
  end
end
