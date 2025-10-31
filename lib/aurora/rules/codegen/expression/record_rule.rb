# frozen_string_literal: true

require_relative "../../base_rule"
require_relative "../../../backend/cpp_lowering/helpers"

module Aurora
  module Rules
    module CodeGen
      module Expression
        # Rule for lowering CoreIR record expressions to C++ struct initialization
        # Example: Point { x: 10, y: 20 } -> Point{10, 20}
        class RecordRule < BaseRule
          include Aurora::Backend::CppLoweringHelpers

          def applies?(node, _context = {})
            node.is_a?(Aurora::CoreIR::RecordExpr)
          end

          def apply(node, context = {})
            lowerer = context[:lowerer]
            type_map = context[:type_map] || {}
            type_registry = context[:type_registry]

            # Map the record type to C++
            type_str = map_type(
              node.type,
              type_map: type_map,
              type_registry: type_registry
            )

            # Recursively lower each field value
            args = node.fields.values.map { |value| lowerer.send(:lower_expression, value) }

            # Generate brace initializer: Point{x_val, y_val}
            CppAst::Nodes::BraceInitializerExpression.new(
              type: type_str,
              arguments: args,
              argument_separators: args.size > 1 ? Array.new(args.size - 1, ", ") : []
            )
          end
        end
      end
    end
  end
end
