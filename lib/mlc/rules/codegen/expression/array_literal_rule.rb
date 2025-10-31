# frozen_string_literal: true

require_relative "../../base_rule"
require_relative "../../../backend/codegen/helpers"

module MLC
  module Rules
    module CodeGen
      module Expression
        # Rule for lowering HighIR array literals to C++ std::vector initializer
        # Example: [1, 2, 3] -> std::vector<int>{1, 2, 3}
        class ArrayLiteralRule < BaseRule
          include MLC::Backend::CodeGenHelpers

          def applies?(node, _context = {})
            node.is_a?(MLC::HighIR::ArrayLiteralExpr)
          end

          def apply(node, context = {})
            lowerer = context[:lowerer]
            type_map = context[:type_map] || {}
            type_registry = context[:type_registry]

            # Get element type and map to C++
            element_type = map_type(
              node.type.element_type,
              type_map: type_map,
              type_registry: type_registry
            )

            # Recursively lower each element
            elements = node.elements.map { |elem| lowerer.send(:lower_expression, elem) }

            # Generate brace initializer: std::vector<int>{1, 2, 3}
            CppAst::Nodes::BraceInitializerExpression.new(
              type: "std::vector<#{element_type}>",
              arguments: elements,
              argument_separators: elements.size > 1 ? Array.new(elements.size - 1, ", ") : []
            )
          end
        end
      end
    end
  end
end
