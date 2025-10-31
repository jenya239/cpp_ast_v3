# frozen_string_literal: true

require_relative "../../base_rule"

module Aurora
  module Rules
    module CodeGen
      module Expression
        # Rule for lowering CoreIR binary expressions to C++ binary operators
        # Contains logic, but delegates recursion to lowerer for child expressions
        class BinaryRule < BaseRule
          def applies?(node, _context = {})
            node.is_a?(Aurora::CoreIR::BinaryExpr)
          end

          def apply(node, context = {})
            lowerer = context[:lowerer]

            # Recursively lower child expressions
            left = lowerer.send(:lower_expression, node.left)
            right = lowerer.send(:lower_expression, node.right)

            CppAst::Nodes::BinaryExpression.new(
              left: left,
              operator: node.op,
              right: right,
              operator_prefix: " ",
              operator_suffix: " "
            )
          end
        end
      end
    end
  end
end
